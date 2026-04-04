#!/usr/bin/env bash
# HyprUI Equalizer — wraps EasyEffects with a 10-band parametric EQ.
# Adapted from nixos-configuration quickshell scripts.
#
# Commands:
#   get                    → print current JSON state
#   set_band <n> <dB>      → move band n (1-10), mark as pending
#   apply                  → write EasyEffects preset, load it
#   preset <name>          → apply a named preset immediately

STATE_FILE="/tmp/hyprui_eq_state.json"
PRESET_DIR="$HOME/.config/easyeffects/output"
PRESET_NAME="hyprui_live_eq"
PRESET_FILE="$PRESET_DIR/${PRESET_NAME}.json"

mkdir -p "$PRESET_DIR"

# ── Initialise state file if missing ─────────────────────────────────────────
if [ ! -f "$STATE_FILE" ]; then
    echo '{"b1":0,"b2":0,"b3":0,"b4":0,"b5":0,"b6":0,"b7":0,"b8":0,"b9":0,"b10":0,"preset":"Flat","pending":false}' > "$STATE_FILE"
fi

# ── Write EasyEffects JSON and load the preset ────────────────────────────────
apply_eq() {
    vals=$(cat "$STATE_FILE")
    python3 - "$vals" <<'PYEOF'
import sys, json
try:
    data = json.loads(sys.argv[1])
    # Map each of the 10 slider indices to the closest of 32 EQ bands
    slider_map = {0:0,1:3,2:6,3:9,4:12,5:15,6:18,7:21,8:24,9:27}
    freqs = [32,40,50,63,80,100,125,160,200,250,315,400,500,630,800,
             1000,1250,1600,2000,2500,3150,4000,5000,6300,8000,10000,
             12500,16000,20000,22000,24000,24000]
    gains = [float(data[f'b{i+1}']) for i in range(10)]
    bands = {}
    for i in range(32):
        freq = freqs[i] if i < len(freqs) else 20000.0
        gain = 0.0
        for s, b in slider_map.items():
            if i == b:
                gain = gains[s]
                break
        bands[f"band{i}"] = {"frequency": freq, "gain": gain, "mode": "Bell",
                              "mute": False, "q": 1.0, "solo": False,
                              "width": 1.0, "slope": "x1"}
    preset = {"output": {"blocklist": [], "plugins_order": ["equalizer"],
              "equalizer": {"bypass": False, "input-gain": 0.0, "output-gain": 0.0,
                            "left": bands, "right": bands, "mode": "IIR",
                            "num-bands": 32, "split-channels": False}}}
    print(json.dumps(preset, indent=2))
except Exception as e:
    import sys as _s; print(e, file=_s.stderr); _s.exit(1)
PYEOF
    rc=$?
    [ $rc -eq 0 ] && python3 - "$vals" > "$PRESET_FILE" <<'PYEOF'
import sys, json
try:
    data = json.loads(sys.argv[1])
    slider_map = {0:0,1:3,2:6,3:9,4:12,5:15,6:18,7:21,8:24,9:27}
    freqs = [32,40,50,63,80,100,125,160,200,250,315,400,500,630,800,
             1000,1250,1600,2000,2500,3150,4000,5000,6300,8000,10000,
             12500,16000,20000,22000,24000,24000]
    gains = [float(data[f'b{i+1}']) for i in range(10)]
    bands = {}
    for i in range(32):
        freq = freqs[i] if i < len(freqs) else 20000.0
        gain = 0.0
        for s, b in slider_map.items():
            if i == b:
                gain = gains[s]
                break
        bands[f"band{i}"] = {"frequency": freq, "gain": gain, "mode": "Bell",
                              "mute": False, "q": 1.0, "solo": False,
                              "width": 1.0, "slope": "x1"}
    preset = {"output": {"blocklist": [], "plugins_order": ["equalizer"],
              "equalizer": {"bypass": False, "input-gain": 0.0, "output-gain": 0.0,
                            "left": bands, "right": bands, "mode": "IIR",
                            "num-bands": 32, "split-channels": False}}}
    print(json.dumps(preset, indent=2))
except Exception as e:
    import sys as _s; print(e, file=_s.stderr); _s.exit(1)
PYEOF
    easyeffects -l "$PRESET_NAME" >/dev/null 2>&1 &
}

save_and_apply() {
    # args: b1..b10 preset_name
    jq -n -c \
        --arg b1 "$1"  --arg b2 "$2"  --arg b3 "$3"  --arg b4 "$4"  --arg b5 "$5" \
        --arg b6 "$6"  --arg b7 "$7"  --arg b8 "$8"  --arg b9 "$9"  --arg b10 "${10}" \
        --arg p "${11}" \
        '{"b1":$b1,"b2":$b2,"b3":$b3,"b4":$b4,"b5":$b5,
          "b6":$b6,"b7":$b7,"b8":$b8,"b9":$b9,"b10":$b10,
          "preset":$p,"pending":false}' > "$STATE_FILE"
    apply_eq
}

cmd=$1; arg1=$2; arg2=$3

case $cmd in
    "get")
        cat "$STATE_FILE"
        ;;
    "set_band")
        # Move one band; mark pending=true, preset=Custom
        tmp=$(cat "$STATE_FILE")
        echo "$tmp" | jq -c --arg v "$arg2" ".b${arg1} = (\$v | tonumber) | .preset = \"Custom\" | .pending = true" \
            > "$STATE_FILE"
        ;;
    "apply")
        # Clear pending flag then write + load the preset
        tmp=$(cat "$STATE_FILE")
        echo "$tmp" | jq -c ".pending = false" > "$STATE_FILE"
        apply_eq
        ;;
    "preset")
        case $arg1 in
            "Flat")    save_and_apply  0  0  0  0  0  0  0  0  0  0  "Flat"    ;;
            "Bass")    save_and_apply  5  7  5  2  1  0  0  0  1  2  "Bass"    ;;
            "Treble")  save_and_apply -2 -1  0  1  2  3  4  5  6  6  "Treble"  ;;
            "Vocal")   save_and_apply -2 -1  1  3  5  5  4  2  1  0  "Vocal"   ;;
            "Pop")     save_and_apply  2  4  2  0  1  2  4  2  1  2  "Pop"     ;;
            "Rock")    save_and_apply  5  4  2 -1 -2 -1  2  4  5  6  "Rock"    ;;
            "Jazz")    save_and_apply  3  3  1  1  1  1  2  1  2  3  "Jazz"    ;;
            "Classic") save_and_apply  0  1  2  2  2  2  1  2  3  4  "Classic" ;;
        esac
        ;;
esac
