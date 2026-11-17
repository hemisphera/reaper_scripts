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

### Noteholder

`Effects/Noteholder` is a JSFX that **latches the chord you play**: notes keep sounding after you let go of the keys, until you start the next chord. It works like a sustain pedal that only lets go when you play something new. You can switch it on and off with a slider or with a dedicated MIDI note, for example a footswitch or a spare pad.

#### How it works

While *Hold Enable* is **On**:

- Every note you play is passed through and added to the **held chord**. Its note-off is swallowed, so the note keeps sounding after you release the key.
- Notes played while at least one key is still down are added to the same chord.
- Once all keys are up, the chord keeps sounding. The **next note you play** first stops all held notes and then starts a new chord.
- Up to **8 notes** are held. A 9th note in the same chord plays normally but is not held: it stops when you release its key.
- Pressing a key again while the chord is still being played restarts that note: the effect sends a note-off for the old note before the new note-on, so no voice is left hanging.
- Notes are told apart by note number **and** MIDI channel, so the same note on two channels is handled as two separate notes.

While *Hold Enable* is **Off**, all MIDI passes through untouched.

Switching hold:

- **On → Off** immediately stops the held notes whose keys are already up. Notes whose keys you are still pressing keep sounding and stop when you release them, like lifting a sustain pedal.
- **Off → On** while keys are pressed turns the notes you are holding into the held chord.

All MIDI other than notes (CCs, pitch bend, program changes, …) always passes through.

#### Sliders

| Slider | Range | Default | Purpose |
|---|---|---|---|
| Hold Enable | Off / On | On | Switches hold on or off. Also toggled by the trigger note. |
| Trigger Note | 0–127 | 60 (middle C) | Note number that toggles *Hold Enable*. |
| Trigger Channel | 1–16 | 1 | MIDI channel the trigger note must arrive on. |

#### Trigger note

Each note-on of *Trigger Note* on *Trigger Channel* toggles *Hold Enable*, which you can see on the slider. The trigger note's own note-on and note-off are swallowed, so it never sounds. The same note number on **other** channels is treated as a normal note.

To use a sustain-style footswitch or a pad, set it to send a note-on when pressed, and set *Trigger Note* and *Trigger Channel* to match.

#### Example

1. Insert *Noteholder* on an instrument track, before the instrument.
2. Set *Trigger Note* / *Trigger Channel* to a note your footswitch or a spare pad sends.
3. Play a chord and release it: it keeps sounding. Play another chord: the first one stops and the new one is held.
4. Press the trigger to switch hold off: the held chord stops (except keys you are still pressing) and the keyboard plays normally again.
