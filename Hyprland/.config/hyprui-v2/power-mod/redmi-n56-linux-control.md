# Redmi Book Pro 16 2024 (N56) — Linux Hardware Control Reference

**Model:** Xiaomi Redmi Book Pro 16 2024 (TM2309 / N56)  
**CPU:** Intel Core Ultra 7 155H (Meteor Lake, 16 cores, 22 threads)  
**Battery:** SUNWODA BX90, 95.989 Wh  
**BIOS:** RMAMT6B0P0A0A  
**Confirmed:** 2026-03-30

---

## 1. WMAA Protocol

All hardware control goes through a single ACPI method:

```
\_SB.PC00.WMID.WMAA(Arg0=0, Arg1=1, Arg2=10-byte-buffer)
```

**Request buffer layout (10 bytes, all fields little-endian):**

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| 0x00 | u16 | FUN1 | `0xFA00` = GET, `0xFB00` = SET |
| 0x02 | u16 | FUN2 | Subsystem: `0x1000`=battery, `0x0800`=fan, `0x0A00`=mic |
| 0x04 | u16 | FUN3 | Sub-function or mode selector |
| 0x06 | u32 | FUN4 | Value or enable/disable |

**Response buffer layout (32 bytes):**

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| 0x00 | u16 | SGER | `0x8000` = success, `0xE000` = error |
| 0x02 | u16 | FUTR | Echoed FUN2 |
| 0x04 | u16 | FRD0 | Echoed FUN3 or result code |
| 0x06 | u32 | FRD1 | Return value |

**Invocation via acpi_call:**

```bash
# Payload format: b{10 bytes hex, no spaces, little-endian fields}
echo '\_SB.PC00.WMID.WMAA 0 1 b00fb0010020001000000' | sudo tee /proc/acpi/call
sudo cat /proc/acpi/call
```

Payload construction: `b` + FUN1_LE + FUN2_LE + FUN3_LE + FUN4_LE

Example — battery conservation enable:
- FUN1=0xFB00 → `00fb`
- FUN2=0x1000 → `0010`
- FUN3=0x0002 → `0200`
- FUN4=0x00000001 → `01000000`
- Payload: `b00fb001002000100 0000` → `b00fb0010020001000000`

---

## 2. Battery Conservation (80% Charge Limit)

### Confirmed Payloads

```bash
# Enable 80% limit
echo '\_SB.PC00.WMID.WMAA 0 1 b00fb0010020001000000' | sudo tee /proc/acpi/call

# Disable (charge to 100%)
echo '\_SB.PC00.WMID.WMAA 0 1 b00fb0010020000000000' | sudo tee /proc/acpi/call

# Query current state — FRD1 byte[6]: 0x01=ON, 0x00=OFF
echo '\_SB.PC00.WMID.WMAA 0 1 b00fa0010020000000000' | sudo tee /proc/acpi/call
cat /proc/acpi/call
```

**Observed result:** Battery stops at 79% (80% ± 1% hysteresis). Enforced in hardware by the BMS — the charger physically cuts off. Confirmed while charging from 68%, stopped at 79% with `Not charging` status.

### How It Works (DSDT confirmed)

```
WMAA SET FUN2=0x1000 FUN3=0x0002:
  Local0 = ECRD(LONL)          // read EC register LONL
  if FUN4==1: ECWT(Local0|1, LONL)   // set bit 0 → enable
  if FUN4==0: ECWT(Local0&~1, LONL)  // clear bit 0 → disable
```

EC register `LONL` at offset **0xA4** is the control input. `EC[0xCA]` mirrors the state after the call but is not the control register — writing it directly has no effect.

### Persistence (EC RAM cleared on every boot/resume)

```ini
# /etc/systemd/system/redmi-charge-limit.service
[Unit]
Description=Redmi Book Pro 16 Battery Conservation
After=suspend.target hibernate.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'modprobe acpi_call && echo "\_SB.PC00.WMID.WMAA 0 1 b00fb0010020001000000" > /proc/acpi/call'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target suspend.target hibernate.target
```

```bash
sudo systemctl enable --now redmi-charge-limit.service
```

### vs TLP / auto-cpufreq / powertop

| Tool | Can set 80% limit on N56? | Mechanism |
|------|--------------------------|-----------|
| **Our WMAA approach** | **Yes — only option** | Directly programs BMS via ACPI WMAA |
| TLP | No | Uses `charge_control_end_threshold` sysfs — not exposed by this hardware |
| auto-cpufreq | No | CPU governor/EPP only, no charging control |
| powertop | No | Analysis/one-shot tuning tool, no charging support |

The critical distinction: our approach programs the **BMS (Battery Management System) in hardware**. Once set, the limit is enforced by the EC even if the kernel crashes or the service fails — the charger physically stops. TLP's threshold mechanism requires the driver to expose a sysfs node that this laptop does not provide. No third-party tool can replicate this without the WMAA call.

TLP and auto-cpufreq are complementary for CPU/PCIe/USB power management, but cannot replace this for charging control.

---

## 3. Performance Modes

### EC Register Map (Confirmed)

| Symbol | EC Offset | Purpose |
|--------|-----------|---------|
| QFAN | **0x60** | Fan curve profile (confirmed by ec_sys read-back) |
| SMMD | **0x6E** | Special mode flag (0=normal, 5=power-save, 7=AI-scene) |

### Confirmed WMAA Parameters

| Mode | Chinese | FUN1 | FUN2 | FUN3 | FUN4 | QFAN value |
|------|---------|------|------|------|------|-----------|
| Balanced | 均衡 | 0xFB00 | 0x0800 | 0x0001 | 0x00000001 | 0x01 |
| Silent | 静谧 | 0xFB00 | 0x0800 | 0x0002 | 0x00000001 | 0x02 |
| Performance | 极速 | 0xFB00 | 0x0800 | 0x0003 | 0x00000001 | 0x03 |
| Turbo | 狂暴 | 0xFB00 | 0x0800 | 0x0004 | 0x00000001 | 0x04 |

**Read current mode:**
```bash
echo '\_SB.PC00.WMID.WMAA 0 1 b00fa0008000000000000' | sudo tee /proc/acpi/call
cat /proc/acpi/call
# FRD0 byte[4] = 0x01/0x02/0x03/0x04
```

### How It Works (DSDT confirmed)

For FUN3 = 0x01–0x04 (all normal performance modes):
```
ECWT(0, SMMD)        // clear special-mode flag
ECWT(FUN3, QFAN)     // write mode to EC fan controller
QV20(1, 0x16)        // fire WMI event 0x16 (userspace notification)
```

The EC fan controller reads QFAN and applies the corresponding thermal curve. Each mode defines different temperature thresholds at which fan RPM ramps up. Mode does NOT directly set fan speed — it sets the curve. The fan responds when temperatures cross the mode's thresholds under load.

FUN3=0x05 and 0x07 are separate special modes (DPTF/IETM path, not normal use).

### Linux Performance (stress-ng --cpu 4, 20s, measured)

| Mode | Bogo-ops | Governor | RAPL PL1 | EPP |
|------|----------|----------|----------|-----|
| Silent | 141,967 | powersave | 25W | power |
| Turbo | 196,174 | performance | 65W | — |
| **Delta** | **+38.3%** | | | |

Fan audibly ramps under sustained load in Turbo mode. QFAN register confirmed changing at EC offset 0x60.

### acpi_call Payloads

```bash
sudo modprobe acpi_call

echo '\_SB.PC00.WMID.WMAA 0 1 b00fb0008020001000000' | sudo tee /proc/acpi/call  # Silent
echo '\_SB.PC00.WMID.WMAA 0 1 b00fb0008010001000000' | sudo tee /proc/acpi/call  # Balanced
echo '\_SB.PC00.WMID.WMAA 0 1 b00fb0008030001000000' | sudo tee /proc/acpi/call  # Performance
echo '\_SB.PC00.WMID.WMAA 0 1 b00fb0008040001000000' | sudo tee /proc/acpi/call  # Turbo
```

---

## 4. Additional WMAA Functions Discovered

| FUN2 | FUN3 | Direction | Function |
|------|------|-----------|----------|
| 0x1000 | 0x01 | GET | Battery State of Health → FRD1 |
| 0x1000 | 0x03 | GET | Charger power check: FRD1=1 if adapter < 140W |
| 0x0A00 | 0x05 | SET | Mic mute: FUN4=1→unmute, FUN4=0→mute |
| 0x0800 | 0x05 | SET | DPTF power-save special mode (ODV1=5) |
| 0x0800 | 0x07 | SET | DPTF AI-scene special mode (ODV1=6) |

---

## 5. C OSD Tool Integration

### Direct /proc/acpi/call Interface

```c
#include <fcntl.h>
#include <unistd.h>
#include <string.h>

// Returns 0 on success, -1 on error
int wmaa_call(const char *payload, char *response, size_t resp_size) {
    int fd = open("/proc/acpi/call", O_RDWR);
    if (fd < 0) return -1;

    write(fd, payload, strlen(payload));

    lseek(fd, 0, SEEK_SET);
    ssize_t n = read(fd, response, resp_size - 1);
    if (n > 0) response[n] = '\0';

    close(fd);
    return (n > 0) ? 0 : -1;
}

// Example: set Turbo mode
// wmaa_call("\\_SB.PC00.WMID.WMAA 0 1 b00fb0008040001000000", buf, sizeof(buf));
```

### EC Register Direct Read

```c
#include <fcntl.h>
#include <unistd.h>

uint8_t ec_read(int offset) {
    int fd = open("/sys/kernel/debug/ec/ec0/io", O_RDONLY);
    if (fd < 0) return 0xFF;  // error sentinel
    uint8_t val = 0xFF;
    lseek(fd, offset, SEEK_SET);
    read(fd, &val, 1);
    close(fd);
    return val;
}

// Read current performance mode:
// uint8_t mode = ec_read(0x60);  // QFAN: 1=Balanced, 2=Silent, 3=Perf, 4=Turbo

// Read battery level:
// uint8_t soc = ec_read(0x93);   // RSOC
```

### Mode Payloads for C (string constants)

```c
#define WMAA_PREFIX    "\\_SB.PC00.WMID.WMAA 0 1 "

#define PERF_SILENT    WMAA_PREFIX "b00fb0008020001000000"
#define PERF_BALANCED  WMAA_PREFIX "b00fb0008010001000000"
#define PERF_PERF      WMAA_PREFIX "b00fb0008030001000000"
#define PERF_TURBO     WMAA_PREFIX "b00fb0008040001000000"
#define PERF_GET       WMAA_PREFIX "b00fa0008000000000000"

#define CHARGE_ON      WMAA_PREFIX "b00fb0010020001000000"
#define CHARGE_OFF     WMAA_PREFIX "b00fb0010020000000000"
#define CHARGE_GET     WMAA_PREFIX "b00fa0010020000000000"
```

### Required Privileges

Both `/proc/acpi/call` and `/sys/kernel/debug/ec/ec0/io` require root. Options:
- Run OSD daemon as root
- `setuid` wrapper binary (narrow attack surface)
- `polkit` rule granting specific write access to the OSD process
- udev rule: `KERNEL=="ec0", SUBSYSTEM=="acpi"` ... (limited applicability)

The cleanest approach for an OSD tool: a small privileged helper binary that accepts only a mode index and calls the appropriate payload, with the OSD sending it a single integer over a Unix socket.

---

## 6. Key Files

| File | Location | Purpose |
|------|----------|---------|
| `redmi-charge-limit.sh` | `~/` | Toggle/query 80% charge limit |
| `redmi-perf-mode.sh` | `~/` | Set performance mode + governor + EPP + RAPL |
| `redmi-charge-limit.service` | `/etc/systemd/system/` | Persist charge limit across reboots and resumes |
| `ssdt20.dsl` | ACPI dump | WMAA method source — all control paths |
| `dsdt.dsl` | ACPI dump | EC field definitions — QFAN@0x60, SMMD@0x6E, LONL@0xA4 |
