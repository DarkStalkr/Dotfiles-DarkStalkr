#!/usr/bin/env bash
# ical_reader.sh — Parse .ics calendar files and output events as a JSON array.
# Searches GNOME Calendar, Evolution, vdirsyncer, and a few common user paths.
#
# Output format:
#   [{"date":"YYYY-MM-DD","summary":"Event title","desc":"Optional description"}, ...]

set -euo pipefail

SEARCH_DIRS=(
    "$HOME/.local/share/gnome-calendar"
    "$HOME/.local/share/evolution/calendar/system"
    "$HOME/.local/share/evolution/calendar/local"
    "$HOME/.config/vdirsyncer"
    "$HOME/Calendar"
    "$HOME/.calendar"
    "$HOME/.config/calendar"
)

# Accumulate JSON event objects in an array
declare -a events=()

# ─── ICS parser ────────────────────────────────────────────────────────────────
parse_ics() {
    local file="$1"
    local in_event=0
    local dtstart="" summary="" description=""
    # Unfold: join continuation lines (lines that begin with SPACE or TAB)
    local unfolded
    unfolded=$(sed -e 'N; s/\r\n[ \t]//; P; D' "$file" 2>/dev/null | tr -d '\r') || return

    while IFS= read -r line; do
        case "$line" in
            "BEGIN:VEVENT")
                in_event=1
                dtstart=""; summary=""; description=""
                ;;
            "END:VEVENT")
                if [[ $in_event -eq 1 && -n "$summary" && -n "$dtstart" ]]; then
                    # Extract 8-digit date from DTSTART (handles VALUE=DATE and TZID variants)
                    local date_raw
                    date_raw=$(printf '%s' "$dtstart" | grep -oP '\d{8}' | head -1)
                    if [[ -n "$date_raw" ]]; then
                        local yyyy="${date_raw:0:4}"
                        local mm="${date_raw:4:2}"
                        local dd="${date_raw:6:2}"
                        # JSON-safe escaping: backslash, double-quote, control chars
                        local safe_sum
                        safe_sum=$(printf '%s' "$summary" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g')
                        local safe_desc
                        safe_desc=$(printf '%s' "$description" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g' | head -c 300)
                        events+=("{\"date\":\"${yyyy}-${mm}-${dd}\",\"summary\":\"${safe_sum}\",\"desc\":\"${safe_desc}\"}")
                    fi
                fi
                in_event=0
                ;;
        esac

        if [[ $in_event -eq 1 ]]; then
            # Strip property parameters (e.g. DTSTART;TZID=Europe/Madrid:... → keep value after last colon)
            local val="${line#*:}"
            case "$line" in
                DTSTART*)      dtstart="$val" ;;
                SUMMARY*)      summary="${line#SUMMARY:}" ;;
                DESCRIPTION*)  description="${line#DESCRIPTION:}" ;;
            esac
        fi
    done <<< "$unfolded"
}

# ─── Discover .ics files ───────────────────────────────────────────────────────
for dir in "${SEARCH_DIRS[@]}"; do
    [[ -d "$dir" ]] || continue
    while IFS= read -r -d '' ics_file; do
        parse_ics "$ics_file"
    done < <(find "$dir" -name "*.ics" -print0 2>/dev/null)
done

# ─── Emit JSON ────────────────────────────────────────────────────────────────
printf '['
first=1
for ev in "${events[@]}"; do
    [[ $first -eq 0 ]] && printf ','
    printf '%s' "$ev"
    first=0
done
printf ']'
