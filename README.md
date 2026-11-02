# TX-set_RF2

[日本語版 README](README_ja.md)

An EdgeTX color-LCD widget for viewing and adjusting **Throttle RPM** and **Collective Pitch (max)** per flight mode (FM0–FM2) directly from the main screen — with voice feedback.
Designed for RC helicopters running Rotorflight. A **Rotorflight 4.7 master gain** adjustment is planned (see [Roadmap](#roadmap)).

> Derived from my earlier widget `TX-Set2` (VBar NEO era). The Tail Gyro function was removed in this version.

## Features

- Shows Thr RPM and Coll P. for FM0, FM1 and FM2 side by side; the current flight mode is highlighted
- Edit values with two input channels (CH13 / CH11) while the edit switch is in the EDIT position
- Edit/Lock protection through a configurable switch (prevents accidental changes in flight)
- Spoken value after each change, with configurable delay and guard time
- Adapts layout and font size to the widget zone height

| Row | Global Variable | Input channel | Displayed as |
|---|---|---|---|
| ThrRPM | GV1 | CH13 | RPM (rounded down to 10 rpm) |
| Coll P | GV2 | CH11 | degrees, 0 – MaxColl |

Each step changes the GV by ±1 for the **current flight mode**. GV range is clamped to -100…+100:

- `ThrRPM = floor(MaxRPM × (GV + 100) / 2000) × 10`  (GV -100 → 0, GV +100 → MaxRPM)
- `Coll   = MaxColl × (GV + 100) / 200`  (GV -100 → 0°, GV +100 → MaxColl°)

## Requirements

- EdgeTX **2.12** (developed and tested on this version) on a color-LCD radio
- GV1 and GV2 set up for use in your model, with independent values per flight mode
- Two channels (CH13 and CH11) that move beyond ±50 % when you press your "up/down" control, e.g. a momentary switch or trim button routed through a mix. The widget detects an edge where `|value| > 500` (±1024 = ±100 %)

## Installation

1. Copy the `WIDGETS/TXsetRF2` folder to the `/WIDGETS/` directory of your radio's SD card.
   - The folder name must be **8 characters or fewer** (EdgeTX limitation), so it is `TXsetRF2`. The widget is shown as `TX-set_RF2` in the widget list.
2. Restart the radio (or reselect the model).
3. Add the widget to a main view: *Screen setup → select a zone → Widget → TX-set_RF2*.
4. Open the widget settings and choose the **EditSwitch** source.

## Usage

1. Put the edit switch in the EDIT position (value > 500). The header of the current FM turns to the *active* color.
2. Operate CH13 (Thr RPM) or CH11 (Coll P.). The value of the current FM changes by one step and is announced by voice.
3. Put the edit switch back to LOCK to prevent further changes.

## Widget options

| Option | Default | Description |
|---|---|---|
| EditSwitch | – | Source that enables editing (EDIT when value > 500) |
| ColorPast | grey | Color for inactive FM columns / lock state |
| ColorActive | red | Color of the current FM header in EDIT state |
| ColorLabel | white | Color of labels and the current FM values |
| MaxColl | 14 | Collective pitch at GV = +100 (10–16) |
| MaxRPM | 3000 | Throttle RPM at GV = +100 (2000–8000) |
| VoiceDelay | 40 | Delay before announcing a changed value (×10 ms, 0–200) |
| VoiceGuardTime | 70 | Minimum gap between two announcements (×10 ms, 0–300) |

Voice output: Thr RPM is read as the RPM value; Coll P. is read in tenths of a degree (e.g. 123 = 12.3°).

## Roadmap

- [ ] Rotorflight 4.7 master gain adjustment (channel/GV assignment and scaling to be decided once the wizard-generated Adjustment settings are available)

## Disclaimer

Use at your own risk. Always verify values on the bench (motor/rotor stopped, no blades attached) before flying.

## License

[MIT](LICENSE)
