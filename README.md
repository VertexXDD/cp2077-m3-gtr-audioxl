<div align="center">

# cp2077-m3-gtr-audioxl

![Game](https://img.shields.io/badge/Game-Cyberpunk%202077-fcee0a)
![Framework](https://img.shields.io/badge/Framework-CET%20%2F%20AudioXL-purple)
![Version](https://img.shields.io/badge/Version-v1.3-blue)

Custom multi-band **AudioXL & Cyber Engine Tweaks** engine audio controller for the Cyberpunk 2077 BMW M3 GTR mod.

</div>

> [!WARNING]
> **Known Issue — Soundhook Trigger:** On initial vehicle entry, you may occasionally need to press **`Q`** (or cycle camera perspectives between FPP and TPP) once or twice to wake up the AudioXL soundhook.

<details>
<summary><b>Click to view Troubleshooting & Live CET Console Tuning</b></summary>

- **No engine audio when entering the car:** Cycle camera perspective (`Q`) to force the FPP/TPP layer switch and trigger the AudioXL emitter.
- **Adjust volume live in-game:** Open the Cyber Engine Tweaks (CET) overlay, switch to the **Console** tab, and run:
  ```lua
  GetMod("m3_gtr_audio").masterGain = 0.85 -- Default is 0.85 (keep between 0.50 and 1.10)
  ```
- **Run diagnostics / debug logging:**
  ```lua
  GetMod("m3_gtr_audio").Diag("NOW")      -- Prints active voices, emitter status, and AudioXL slot report
  GetMod("m3_gtr_audio").debugLog = true   -- Toggles live telemetry logging in the CET console
  ```

</details>

## DISCLAIMER
This mod is 100% vibecoded with AI. It took 11 hours of troubleshooting to get to a working state, and it is shared as-is.

## WHAT'S INCLUDED
- **Multi-Band Engine Audio Controller (`init.lua`):** Smoothed 30 Hz AudioXL controller with persistent single-layer voices and automatic gain-ceiling clip protection.
- **Full Exterior (TPP) & Interior (FPP) Mixing:** Separate exterior and interior RPM layers across `idle`, `very low`, `low`, `mid`, and `high` bands, plus redline splutter and shift/lift-off backfire pops.
- **AudioXL Sound Manifest (`sounds.json`):** Pre-configured 24-sample AudioXL sound definition bank.

> [!NOTE]
> **About the Floating Car Fix:** This repository does **not** bundle or overwrite `ctrlsec_M3_GTR_MostWanted.yaml` out of respect for the base mod author's permissions. To fix the floating tires so they sit flush on the road, follow the pinned instructions on the base BMW M3 GTR Nexus Mods page.

## REQUIREMENTS
- **Base Vehicle Mod:** `'01 BMW M3 GTR 'Most Wanted'` standalone vehicle mod (Nexus Mods)
- **RED4ext**
- **AudioXL**
- **Cyber Engine Tweaks (CET)**
- **Redscript**
- **TweakXL**

## INSTALL
1. **Download the Release:** Go to the [**Releases**](../../releases) page and download the latest release `.zip` *(do not use GitHub's automatic "Source code" zip, as it wraps files in an extra parent folder)*.
2. **Extract to Game Root:** Extract the **`bin\`** and **`red4ext\`** folders directly into your root `Cyberpunk 2077\` directory. No base mod files will be overwritten.
3. *(If audio `.wav` files are not bundled in your release)* Download the M3 GTR sound pack from [cyxapik on Overtake.gg](https://www.overtake.gg/downloads/bmw-m3-gtr-sound-mod.44140/) and place the `.wav` files alongside `sounds.json`.

### Expected Folder Structure
```text
Cyberpunk 2077/
├── bin/
│   └── x64/
│       └── plugins/
│           └── cyber_engine_tweaks/
│               └── mods/
│                   └── m3_gtr_audio/
│                       └── init.lua
└── red4ext/
    └── plugins/
        └── AudioXL/
            └── sfx/
                └── m3_gtr_audio/
                    ├── sounds.json
                    └── (*.wav sound files)
```

## PATCH NOTES (v1.3)
- **Reversing Audio Fixed:** Added synthetic reverse RPM scaling (`reverseMaxRPM`) so reversing builds engine pitch naturally instead of pinning at idle RPM.
- **Braking, Sliding & Lift-Off Overrun Fixed:** Added an engaged-drivetrain engine braking RPM floor and boosted `off_*` overrun bands so deceleration, drifting, and throttle lift-off cut clearly over tire screech.
- **Shift & Lift-Off Backfires:** Added dynamic backfire triggers on high-RPM upshifts and sharp throttle lift-offs, plus redline splutter above `7550 RPM`.
- **Startup Hook Recovery:** Added post-mount emitter settle delays and `Position()`-verified playback checks to automatically retry stalled AudioXL emitters on vehicle entry.

## KNOWN ISSUES
1. **Q / Perspective Switch Trigger:** Pressing `Q` / switching camera perspectives may still be required occasionally to trigger the AudioXL soundhook on initial mount.

## CREDITS
- **[cyxapik](https://www.overtake.gg/downloads/bmw-m3-gtr-sound-mod.44140/)** on Overtake.gg — Original BMW M3 GTR engine, overrun, splutter, and backfire `.wav` sound files.
- **ctxrlsec** — Base `'01 BMW M3 GTR 'Most Wanted'` vehicle mod for Cyberpunk 2077.