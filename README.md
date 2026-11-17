# REAPER Scripts
Scripts for Cockos REAPER

Contains the following scripts:
- `Create Markers at Media Item Start`: Creates markers at the start of every media item on the selected tracks. Removes all other markers when run. The marker's name is set to the filename (without extension) of the active take of the media item.

## Effects

### Relativator

`Effects/Relativator` is a JSFX that turns **relative (endless encoder) MIDI CC messages** into **absolute values** stored in 8 sliders. Use it when a controller has endless knobs that send "turned left / turned right" messages, but the thing you want to control expects an ordinary 0–127 value.

The resulting slider values can be routed anywhere REAPER allows: parameter modulation/linking, automation, or reading them from other scripts.

#### How it works

- The plugin listens to **8 consecutive CC numbers**, starting at *Base CC Number*. With the default base of `14`, CC 14 drives slot `+0`, CC 15 drives slot `+1`, and so on up to CC 21 → `+7`.
- Every CC message in that range adjusts the matching *CC +n Value* slider up or down. The result is clamped to 0–127.
- Those CC messages are **consumed**: they are not passed on. All other MIDI (other CC numbers, notes, program changes, …) passes through unchanged.
- The MIDI channel is ignored. A matching CC on any channel is handled.

#### Sliders

| Slider | Range | Default | Purpose |
|---|---|---|---|
| Multiplier | 0–8 | 8 | Sensitivity. Each encoder tick moves the value by `step × Multiplier / 8`. `8` = full speed, `1` = one eighth of the speed, `0` = frozen. |
| Base CC Number | 0–120 | 14 | First of the 8 CC numbers the plugin reacts to. Capped at 120 so that all 8 slots (base … base + 7) stay within CC 0–127. |
| CC +0 … CC +7 Value | 0–127 | 0 | The absolute output values, one per CC. You can also set them by hand to give a knob a starting position. |

#### Encoder value format

The plugin expects encoders in **two's complement** relative mode, which many controllers call "Relative 1" or "Relative (2's comp.)". Set your encoders to that mode. The incoming CC value encodes both the direction and the step size:

| Incoming value | Meaning | Examples |
|---|---|---|
| 0 | no change | |
| 1 – 63 | up by the value | 1 → +1, 10 → +10, 63 → +63 |
| 64 – 127 | down by `128 − value` | 127 → −1, 120 → −8, 64 → −64 |

The step is then scaled by *Multiplier* (see above).

#### Precision

Values are tracked internally as fractions, so low multipliers still add up over several ticks (e.g. with Multiplier `2`, each `+1` tick adds 0.25, so four ticks add a full 1). The slider shows the value rounded to the nearest whole number. Changing any slider by hand resets the internal values to the whole numbers shown, which discards any partial progress.

#### Example

1. Set your controller's encoders to send relative two's complement on CC 14–21.
2. Insert *Relativator* on the track that receives the controller's MIDI input.
3. Optionally lower *Multiplier* for finer control (default `8` = full speed).
4. Turn an encoder and watch the matching *CC +n Value* slider move.
5. On the target FX parameter, open *Parameter modulation/MIDI link* → *Link from MIDI or FX parameter* and select the matching Relativator slider.
