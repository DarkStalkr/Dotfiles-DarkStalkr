#!/usr/bin/env bash

# Paths
cache_dir="$HOME/.cache/quickshell/weather"
json_file="${cache_dir}/weather.json"
view_file="${cache_dir}/view_id"

mkdir -p "${cache_dir}"

# ─── WMO code → icon (Nerd Font) ────────────────────────────────────────────
wmo_icon() {
    local code=$1 hour=${2:-12}
    local suffix="d"
    [[ $hour -ge 0 && $hour -lt 6 ]] && suffix="n"
    [[ $hour -ge 20 ]] && suffix="n"

    case $code in
        0)           [[ $suffix == "d" ]] && echo "" || echo "" ;;  # clear
        1|2)         echo "" ;;   # partly cloudy
        3)           echo "" ;;   # overcast
        45|48)       echo "" ;;   # fog
        51|53|55)    echo "" ;;   # drizzle
        56|57)       echo "" ;;   # freezing drizzle
        61|63|65)    echo "" ;;   # rain
        66|67)       echo "" ;;   # freezing rain
        71|73|75|77) echo "" ;;   # snow
        80|81|82)    echo "" ;;   # rain showers
        85|86)       echo "" ;;   # snow showers
        95|96|99)    echo "" ;;   # thunderstorm
        *)           echo "" ;;
    esac
}

# ─── WMO code → hex color ────────────────────────────────────────────────────
wmo_hex() {
    local code=$1
    case $code in
        0)           echo "#f9e2af" ;;  # sunny yellow
        1|2)         echo "#bac2de" ;;  # partly cloudy grey-blue
        3)           echo "#9399b2" ;;  # overcast grey
        45|48)       echo "#84afdb" ;;  # fog blue-grey
        51|53|55|56|57) echo "#74c7ec" ;;  # drizzle blue
        61|63|65|66|67) echo "#74c7ec" ;;  # rain blue
        71|73|75|77) echo "#cdd6f4" ;;  # snow white
        80|81|82)    echo "#74c7ec" ;;  # showers blue
        85|86)       echo "#cdd6f4" ;;  # snow showers
        95|96|99)    echo "#f9e2af" ;;  # thunder yellow
        *)           echo "#cdd6f4" ;;
    esac
}

# ─── WMO code → description ──────────────────────────────────────────────────
wmo_desc() {
    local code=$1
    case $code in
        0)           echo "Clear Sky" ;;
        1)           echo "Mainly Clear" ;;
        2)           echo "Partly Cloudy" ;;
        3)           echo "Overcast" ;;
        45)          echo "Foggy" ;;
        48)          echo "Icy Fog" ;;
        51)          echo "Light Drizzle" ;;
        53)          echo "Drizzle" ;;
        55)          echo "Heavy Drizzle" ;;
        56|57)       echo "Freezing Drizzle" ;;
        61)          echo "Light Rain" ;;
        63)          echo "Rain" ;;
        65)          echo "Heavy Rain" ;;
        66|67)       echo "Freezing Rain" ;;
        71)          echo "Light Snow" ;;
        73)          echo "Snow" ;;
        75)          echo "Heavy Snow" ;;
        77)          echo "Snow Grains" ;;
        80)          echo "Light Showers" ;;
        81)          echo "Showers" ;;
        82)          echo "Heavy Showers" ;;
        85|86)       echo "Snow Showers" ;;
        95)          echo "Thunderstorm" ;;
        96|99)       echo "Severe Thunderstorm" ;;
        *)           echo "Unknown" ;;
    esac
}

# ─── Fetch & build forecast JSON ─────────────────────────────────────────────
get_data() {
    # Get coordinates from ipinfo.io
    local loc_json
    loc_json=$(curl -sf --max-time 5 "https://ipinfo.io/json") || { echo "ipinfo failed" >&2; return 1; }
    local loc
    loc=$(echo "$loc_json" | jq -r '.loc // "0,0"')
    local lat lon
    lat=$(echo "$loc" | cut -d',' -f1)
    lon=$(echo "$loc" | cut -d',' -f2)

    # Fetch forecast from open-meteo (free, no API key)
    local api_url="https://api.open-meteo.com/v1/forecast"
    api_url+="?latitude=${lat}&longitude=${lon}"
    api_url+="&daily=weather_code,temperature_2m_max,temperature_2m_min,apparent_temperature_max,wind_speed_10m_max,precipitation_probability_max"
    api_url+="&hourly=temperature_2m,weather_code"
    api_url+="&timezone=auto&forecast_days=5"

    local raw
    raw=$(curl -sf --max-time 10 "$api_url") || { echo "open-meteo failed" >&2; return 1; }

    # Validate response
    local num_days
    num_days=$(echo "$raw" | jq '.daily.time | length' 2>/dev/null) || return 1
    [[ $num_days -lt 1 ]] && return 1

    # Build final JSON array
    local final_json="["
    local counter=0

    for i in $(seq 0 $((num_days - 1))); do
        local d
        d=$(echo "$raw" | jq -r ".daily.time[$i]")

        local d_code max_t min_t feels_like wind pop
        d_code=$(echo "$raw" | jq -r ".daily.weather_code[$i]")
        max_t=$(printf "%.1f" "$(echo "$raw" | jq -r ".daily.temperature_2m_max[$i]")")
        min_t=$(printf "%.1f" "$(echo "$raw" | jq -r ".daily.temperature_2m_min[$i]")")
        feels_like=$(printf "%.1f" "$(echo "$raw" | jq -r ".daily.apparent_temperature_max[$i]")")
        wind=$(printf "%.0f" "$(echo "$raw" | jq -r ".daily.wind_speed_10m_max[$i]")")
        pop=$(printf "%.0f" "$(echo "$raw" | jq -r ".daily.precipitation_probability_max[$i] // 0")")

        local f_day f_full f_date
        f_day=$(date -d "$d" "+%a")
        f_full=$(date -d "$d" "+%A")
        f_date=$(date -d "$d" "+%d %b")

        local f_icon f_hex f_desc
        f_icon=$(wmo_icon "$d_code" 12)
        f_hex=$(wmo_hex "$d_code")
        f_desc=$(wmo_desc "$d_code")

        # Build hourly slots (every 3 hours = indices 0,3,6,9,...23 for each day)
        local day_start=$(( i * 24 ))
        local hourly_json="["
        local first_slot=1
        for h in 0 3 6 9 12 15 18 21; do
            local idx=$(( day_start + h ))
            local h_time
            h_time=$(printf "%02d:00" "$h")
            local h_temp h_code h_icon h_hex
            h_temp=$(printf "%.1f" "$(echo "$raw" | jq -r ".hourly.temperature_2m[$idx] // 0")")
            h_code=$(echo "$raw" | jq -r ".hourly.weather_code[$idx] // 0")
            h_icon=$(wmo_icon "$h_code" "$h")
            h_hex=$(wmo_hex "$h_code")

            [[ $first_slot -eq 0 ]] && hourly_json+=","
            hourly_json+="{\"time\":\"${h_time}\",\"temp\":\"${h_temp}\",\"icon\":\"${h_icon}\",\"hex\":\"${h_hex}\"}"
            first_slot=0
        done
        hourly_json+="]"

        [[ $counter -gt 0 ]] && final_json+=","
        final_json+=$(printf '{
            "id": "%s",
            "day": "%s",
            "day_full": "%s",
            "date": "%s",
            "max": "%s",
            "min": "%s",
            "feels_like": "%s",
            "wind": "%s",
            "humidity": "60",
            "pop": "%s",
            "icon": "%s",
            "hex": "%s",
            "desc": "%s",
            "hourly": %s
        }' "$counter" "$f_day" "$f_full" "$f_date" "$max_t" "$min_t" "$feels_like" "$wind" "$pop" "$f_icon" "$f_hex" "$f_desc" "$hourly_json")

        ((counter++))
    done
    final_json+="]"

    echo "{ \"forecast\": ${final_json} }" > "${json_file}"
}

# ─── Mode handling ────────────────────────────────────────────────────────────
case "$1" in
    --getdata)
        get_data
        ;;

    --json)
        CACHE_LIMIT=900  # 15 minutes
        if [ -f "$json_file" ]; then
            file_time=$(stat -c %Y "$json_file")
            current_time=$(date +%s)
            diff=$((current_time - file_time))
            if [ $diff -gt $CACHE_LIMIT ]; then
                get_data &
            fi
            cat "$json_file"
        else
            get_data
            [ -f "$json_file" ] && cat "$json_file" || echo '{"forecast": []}'
        fi
        ;;

    --view-listener)
        [ ! -f "$view_file" ] && echo "0" > "$view_file"
        tail -F "$view_file"
        ;;

    --nav)
        [ ! -f "$view_file" ] && echo "0" > "$view_file"
        current=$(cat "$view_file")
        direction=$2
        max_idx=4
        if [[ "$direction" == "next" ]]; then
            [ "$current" -lt "$max_idx" ] && echo $((current + 1)) > "$view_file"
        elif [[ "$direction" == "prev" ]]; then
            [ "$current" -gt 0 ] && echo $((current - 1)) > "$view_file"
        fi
        ;;

    --icon)
        [ -f "$json_file" ] && jq -r '.forecast[0].icon' "$json_file" || echo ""
        ;;

    --temp)
        [ -f "$json_file" ] && t=$(jq -r '.forecast[0].max' "$json_file") && echo "${t}°C" || echo ""
        ;;

    --hex)
        [ -f "$json_file" ] && jq -r '.forecast[0].hex' "$json_file" || echo "#cdd6f4"
        ;;

    --current-icon)
        curr_hour=$(date +%H | sed 's/^0//')
        if [ -f "$json_file" ]; then
            jq -r --argjson h "$curr_hour" \
                '(.forecast[0].hourly | map(select((.time | split(":")[0] | tonumber) <= $h)) | last) // .forecast[0].hourly[0] | .icon' \
                "$json_file"
        else
            echo ""
        fi
        ;;

    --current-temp)
        curr_hour=$(date +%H | sed 's/^0//')
        if [ -f "$json_file" ]; then
            t=$(jq -r --argjson h "$curr_hour" \
                '(.forecast[0].hourly | map(select((.time | split(":")[0] | tonumber) <= $h)) | last) // .forecast[0].hourly[0] | .temp' \
                "$json_file")
            echo "${t}°C"
        else
            echo ""
        fi
        ;;

    --current-hex)
        curr_hour=$(date +%H | sed 's/^0//')
        if [ -f "$json_file" ]; then
            jq -r --argjson h "$curr_hour" \
                '(.forecast[0].hourly | map(select((.time | split(":")[0] | tonumber) <= $h)) | last) // .forecast[0].hourly[0] | .hex' \
                "$json_file"
        else
            echo "#cdd6f4"
        fi
        ;;

    *)
        echo "Usage: $0 [--json|--getdata|--nav next|prev|--icon|--temp|--hex|--current-icon|--current-temp|--current-hex]"
        exit 1
        ;;
esac
