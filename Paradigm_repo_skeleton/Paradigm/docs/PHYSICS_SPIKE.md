# Physics Spike Acceptance Criteria

The first playable table is intentionally greybox.

## Required geometry

- tilted rectangular playfield
- left/right flippers
- launch lane and plunger/launcher
- two slingshot zones
- three bumpers
- one ramp with meaningful vertical elevation
- side walls / guides
- bottom drain

## Pass criteria

- Flippers react immediately and independently.
- The same shot can be repeated with broadly consistent results.
- Ball does not routinely tunnel through walls, flippers or bumpers at expected gameplay speeds.
- Ramp entry and exit are stable.
- Ball cannot become permanently trapped through ordinary play.
- Drain detection is reliable.
- Controller and keyboard both work.
- 120 Hz physics remains performant on a normal development PC.

## Tuning philosophy

Feel beats realism. Real pinball behavior is the reference, but parameters may be exaggerated for responsiveness and readability.
