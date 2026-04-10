// power-mod-helper.c — Privileged helper for the hyprui-v2 power-mod OSD.
// Installed as setuid root at /usr/local/bin/power-mod-helper.
//
// Usage:
//   power-mod-helper set <0|1|2|3>          apply mode (fan + governor + EPP + RAPL + wifi)
//   power-mod-helper query                  print current mode index (0-3) to stdout
//   power-mod-helper charge on|off|query    BMS 80% conservation toggle
//
// Mode map:
//   0 = Silent      QFAN 0x02, powersave + EPP=power,               25 W PL1, WiFi PM on
//   1 = Balanced    QFAN 0x01, powersave + EPP=balance_power,       45 W PL1, WiFi PM off
//   2 = Performance QFAN 0x03, powersave + EPP=balance_performance, 64 W PL1, WiFi PM off
//   3 = Turbo       QFAN 0x04, performance (no EPP),                65 W PL1, WiFi PM off
//
// Revision notes (vs RedmiBook_ReverseEngineer/power-mod-helper.c):
//   * clearenv() at startup — strips inherited PATH/IFS/etc. from caller.
//   * ensure_acpi_call() now access()-checks /proc/acpi/call first; the modprobe
//     fork only happens on the very first invocation after boot.
//   * write_file() loops until the full payload is written.
//   * WiFi interface is auto-detected from /sys/class/net/<iface>/wireless.
//   * Charge query opens /proc/acpi/call exactly once (write payload, lseek, read).
//   * query_mode() returns -1 on a genuinely unknown state instead of silently
//     reporting Silent; main() exits non-zero so the OSD can show "unknown".
//   * Diagnostics go to syslog so they survive being launched via execDetached.
//   * WiFi PM transitions are skipped when the cached state already matches.

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <stdint.h>
#include <glob.h>
#include <syslog.h>
#include <errno.h>
#include <dirent.h>

// ─── Paths ────────────────────────────────────────────────────────────────────
#define ACPI_CALL_PATH    "/proc/acpi/call"
#define EC_IO_PATH        "/sys/kernel/debug/ec/ec0/io"
#define EC_QFAN_OFFSET    0x60
#define STATE_FILE        "/run/power-mod-state"
#define WIFI_STATE_FILE   "/run/power-mod-wifi-state"
#define CHARGE_STATE_FILE "/run/power-mod-charge-state"
#define IW_PATH           "/usr/bin/iw"
#define MODPROBE_PATH     "/usr/bin/modprobe"

#define RAPL_PL1_PATH     "/sys/class/powercap/intel-rapl:0/constraint_0_power_limit_uw"
#define RAPL_PL2_PATH     "/sys/class/powercap/intel-rapl:0/constraint_1_power_limit_uw"
#define GOV_GLOB          "/sys/devices/system/cpu/cpu*/cpufreq/scaling_governor"
#define EPP_GLOB          "/sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference"

// ─── Mode configuration ───────────────────────────────────────────────────────
typedef struct {
    const char *wmaa_payload;
    const char *governor;
    const char *epp;          // NULL skips
    long        rapl_pl1_uw;
    long        rapl_pl2_uw;
    int         wifi_pm;      // 1 = on, 0 = off
} ModeConfig;

static const ModeConfig MODES[4] = {
    /* 0 Silent      */ {
        "\\_SB.PC00.WMID.WMAA 0 1 b00fb0008020001000000",
        "powersave", "power", 25000000L, 64000000L, 1
    },
    /* 1 Balanced    */ {
        "\\_SB.PC00.WMID.WMAA 0 1 b00fb0008010001000000",
        "powersave", "balance_power", 45000000L, 90000000L, 0
    },
    /* 2 Performance */ {
        "\\_SB.PC00.WMID.WMAA 0 1 b00fb0008030001000000",
        "powersave", "balance_performance", 64000000L, 115000000L, 0
    },
    /* 3 Turbo       */ {
        "\\_SB.PC00.WMID.WMAA 0 1 b00fb0008040001000000",
        "performance", NULL, 65000000L, 115000000L, 0
    },
};

// EC QFAN values are 1-based and reordered relative to our index.
static int qfan_to_index(uint8_t qfan) {
    switch (qfan) {
        case 0x01: return 1;  // Balanced
        case 0x02: return 0;  // Silent
        case 0x03: return 2;  // Performance
        case 0x04: return 3;  // Turbo
        default:   return -1;
    }
}

// ─── Low-level write helpers ──────────────────────────────────────────────────

// write_file: write the entire payload, retrying on partial writes / EINTR.
static int write_file(const char *path, const char *value) {
    int fd = open(path, O_WRONLY);
    if (fd < 0) return -1;

    size_t total = strlen(value);
    size_t done  = 0;
    while (done < total) {
        ssize_t n = write(fd, value + done, total - done);
        if (n < 0) {
            if (errno == EINTR) continue;
            close(fd);
            return -1;
        }
        if (n == 0) { close(fd); return -1; }
        done += (size_t)n;
    }
    close(fd);
    return 0;
}

// Write value to every file matching a glob pattern. Files that cannot be
// opened (offline CPUs, locked sysfs nodes) are silently skipped.
static void write_glob(const char *pattern, const char *value) {
    glob_t g;
    if (glob(pattern, GLOB_NOSORT, NULL, &g) != 0) return;
    for (size_t i = 0; i < g.gl_pathc; i++)
        write_file(g.gl_pathv[i], value);
    globfree(&g);
}

// ─── Privileged operations ────────────────────────────────────────────────────

// Ensure /proc/acpi/call is available. Fast path: skip the fork entirely
// when the file already exists (the common case after the first boot-time call).
static void ensure_acpi_call(void) {
    if (access(ACPI_CALL_PATH, F_OK) == 0) return;

    pid_t pid = fork();
    if (pid == 0) {
        int devnull = open("/dev/null", O_WRONLY);
        if (devnull >= 0) { dup2(devnull, STDERR_FILENO); close(devnull); }
        char *args[] = { (char *)MODPROBE_PATH, (char *)"acpi_call", NULL };
        execv(MODPROBE_PATH, args);
        _exit(127);
    } else if (pid > 0) {
        waitpid(pid, NULL, 0);
    }

    if (access(ACPI_CALL_PATH, F_OK) != 0)
        syslog(LOG_WARNING, "/proc/acpi/call still missing after modprobe acpi_call");
}

// Write a WMAA payload to /proc/acpi/call (fire-and-forget).
static int wmaa_set(const char *payload) {
    int fd = open(ACPI_CALL_PATH, O_WRONLY);
    if (fd < 0) {
        syslog(LOG_ERR, "open %s: %s", ACPI_CALL_PATH, strerror(errno));
        return -1;
    }
    ssize_t n = write(fd, payload, strlen(payload));
    close(fd);
    if (n < 0) {
        syslog(LOG_ERR, "write acpi_call: %s", strerror(errno));
        return -1;
    }
    return 0;
}

// Detect the first wireless interface by scanning /sys/class/net.
static int detect_wifi_iface(char *out, size_t buf_size) {
    DIR *d = opendir("/sys/class/net");
    if (!d) return -1;

    struct dirent *e;
    while ((e = readdir(d))) {
        if (e->d_name[0] == '.') continue;
        size_t nlen = strnlen(e->d_name, sizeof(e->d_name));
        if (nlen == 0 || nlen >= buf_size) continue;
        char path[512];
        snprintf(path, sizeof(path), "/sys/class/net/%.*s/wireless",
                 (int)nlen, e->d_name);
        if (access(path, F_OK) == 0) {
            memcpy(out, e->d_name, nlen);
            out[nlen] = '\0';
            closedir(d);
            return 0;
        }
    }
    closedir(d);
    return -1;
}

// Read cached WiFi PM state to avoid redundant iw forks.
static int read_cached_wifi_pm(void) {
    int fd = open(WIFI_STATE_FILE, O_RDONLY);
    if (fd < 0) return -1;
    char buf[8] = {0};
    ssize_t n = read(fd, buf, sizeof(buf) - 1);
    close(fd);
    if (n <= 0) return -1;
    if (buf[0] == '1') return 1;
    if (buf[0] == '0') return 0;
    return -1;
}

static void write_cached_wifi_pm(int enable) {
    int fd = open(WIFI_STATE_FILE, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd < 0) return;
    char c = enable ? '1' : '0';
    (void)!write(fd, &c, 1);
    close(fd);
}

// Toggle WiFi PM via iw, only when the requested state differs from cache.
static void set_wifi_pm(int enable) {
    if (read_cached_wifi_pm() == enable) return;

    char iface[64];
    if (detect_wifi_iface(iface, sizeof(iface)) != 0) {
        syslog(LOG_INFO, "no wireless interface found, skipping WiFi PM");
        return;
    }

    pid_t pid = fork();
    if (pid == 0) {
        char *args[] = {
            (char *)IW_PATH, (char *)"dev", iface,
            (char *)"set", (char *)"power_save",
            enable ? (char *)"on" : (char *)"off",
            NULL
        };
        int devnull = open("/dev/null", O_WRONLY);
        if (devnull >= 0) {
            dup2(devnull, STDOUT_FILENO);
            dup2(devnull, STDERR_FILENO);
            close(devnull);
        }
        execv(IW_PATH, args);
        _exit(127);
    } else if (pid > 0) {
        int status;
        waitpid(pid, &status, 0);
        if (WIFEXITED(status) && WEXITSTATUS(status) == 0)
            write_cached_wifi_pm(enable);
    }
}

// Write RAPL PL1/PL2. Silently tolerated when firmware locks the files.
static void set_rapl(long pl1_uw, long pl2_uw) {
    char buf[32];
    snprintf(buf, sizeof(buf), "%ld", pl1_uw);
    write_file(RAPL_PL1_PATH, buf);
    snprintf(buf, sizeof(buf), "%ld", pl2_uw);
    write_file(RAPL_PL2_PATH, buf);
}

// Persist mode index for the unprivileged OSD / QML poller to read.
static void write_state(int mode) {
    int fd = open(STATE_FILE, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd < 0) return;
    char c = (char)('0' + mode);
    (void)!write(fd, &c, 1);
    close(fd);
}

// ─── Charge limit (BMS conservation) ─────────────────────────────────────────

// Query the hardware charge-limit state with a single open()/write/lseek/read.
// Returns 1 = ON, 0 = OFF, -1 on error.
static int wmaa_query_charge(void) {
    int fd = open(ACPI_CALL_PATH, O_RDWR);
    if (fd < 0) return -1;

    const char *payload = "\\_SB.PC00.WMID.WMAA 0 1 b00fa0010020000000000";
    if (write(fd, payload, strlen(payload)) < 0) { close(fd); return -1; }
    if (lseek(fd, 0, SEEK_SET) < 0)              { close(fd); return -1; }

    char buf[512] = {0};
    ssize_t n = read(fd, buf, sizeof(buf) - 1);
    close(fd);
    if (n <= 0) return -1;

    // Response format: "{ 0xNN, 0xNN, ... }". byte[6] = FRD1 low.
    if (strncmp(buf, "{ ", 2) != 0) return -1;
    char *p = buf;
    for (int i = 0; i <= 6; i++) {
        p = strstr(p, "0x");
        if (!p) return -1;
        if (i == 6) {
            unsigned int val = 0;
            if (sscanf(p, "0x%x", &val) != 1) return -1;
            return (val == 0x01) ? 1 : 0;
        }
        p += 2;
    }
    return -1;
}

static int set_charge_limit(int enable) {
    ensure_acpi_call();

    const char *payload = enable
        ? "\\_SB.PC00.WMID.WMAA 0 1 b00fb0010020001000000"
        : "\\_SB.PC00.WMID.WMAA 0 1 b00fb0010020000000000";

    if (wmaa_set(payload) != 0) return 1;

    int fd = open(CHARGE_STATE_FILE, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd >= 0) {
        const char *s = enable ? "on" : "off";
        (void)!write(fd, s, strlen(s));
        close(fd);
    }
    return 0;
}

// Apply all settings for a given mode index.
static int set_mode(int idx) {
    if (idx < 0 || idx > 3) return 1;
    const ModeConfig *m = &MODES[idx];

    ensure_acpi_call();

    if (wmaa_set(m->wmaa_payload) != 0) {
        syslog(LOG_ERR, "WMAA call failed for mode %d", idx);
        return 1;
    }

    write_glob(GOV_GLOB, m->governor);
    if (m->epp) write_glob(EPP_GLOB, m->epp);
    set_rapl(m->rapl_pl1_uw, m->rapl_pl2_uw);
    set_wifi_pm(m->wifi_pm);
    write_state(idx);
    return 0;
}

// ─── Query current mode ───────────────────────────────────────────────────────
// EC QFAN is the authoritative source. Falls back to /run/power-mod-state
// only when the EC is not readable. Returns -1 if the state is genuinely
// unknown so the caller can decide how to handle it.
static int query_mode(void) {
    int fd = open(EC_IO_PATH, O_RDONLY);
    if (fd >= 0) {
        if (lseek(fd, EC_QFAN_OFFSET, SEEK_SET) == EC_QFAN_OFFSET) {
            uint8_t qfan = 0xFF;
            if (read(fd, &qfan, 1) == 1) {
                close(fd);
                return qfan_to_index(qfan);
            }
        }
        close(fd);
    }

    fd = open(STATE_FILE, O_RDONLY);
    if (fd >= 0) {
        char c = '0';
        ssize_t n = read(fd, &c, 1);
        close(fd);
        if (n == 1) {
            int idx = c - '0';
            if (idx >= 0 && idx <= 3) return idx;
        }
    }

    return -1;
}

// ─── Entry point ─────────────────────────────────────────────────────────────
int main(int argc, char *argv[]) {
    // setuid hardening: scrub the inherited environment before doing anything.
    // glibc clears LD_* under AT_SECURE; PATH/IFS/etc. survive without this.
    clearenv();

    openlog("power-mod-helper", LOG_PID, LOG_DAEMON);

    if (argc < 2) {
        fprintf(stderr, "Usage: power-mod-helper set <0-3> | query | charge on|off|query\n");
        return 1;
    }

    if (strcmp(argv[1], "query") == 0 && argc == 2) {
        int mode = query_mode();
        if (mode < 0) {
            printf("unknown\n");
            return 2;
        }
        printf("%d\n", mode);
        return 0;
    }

    if (strcmp(argv[1], "set") == 0 && argc == 3) {
        if (argv[2][0] < '0' || argv[2][0] > '3' || argv[2][1] != '\0') {
            fprintf(stderr, "[helper] mode must be 0, 1, 2, or 3\n");
            return 1;
        }
        return set_mode(argv[2][0] - '0');
    }

    if (strcmp(argv[1], "charge") == 0 && argc == 3) {
        if (strcmp(argv[2], "on")  == 0) return set_charge_limit(1);
        if (strcmp(argv[2], "off") == 0) return set_charge_limit(0);
        if (strcmp(argv[2], "query") == 0) {
            ensure_acpi_call();
            int state = wmaa_query_charge();
            if (state < 0) {
                int fd = open(CHARGE_STATE_FILE, O_RDONLY);
                if (fd >= 0) {
                    char buf[8] = {0};
                    (void)!read(fd, buf, sizeof(buf) - 1);
                    close(fd);
                    printf("%s\n", (buf[0] == 'o' && buf[1] == 'n') ? "on" : "off");
                    return 0;
                }
                printf("off\n");
                return 0;
            }
            printf("%s\n", state ? "on" : "off");
            return 0;
        }
        fprintf(stderr, "Usage: power-mod-helper charge on|off|query\n");
        return 1;
    }

    fprintf(stderr, "Usage: power-mod-helper set <0-3> | query | charge on|off|query\n");
    return 1;
}
