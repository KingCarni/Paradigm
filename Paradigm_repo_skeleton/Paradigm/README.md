# Paradigm

**Working title:** Paradigm / Paradigm Pinball  
**Engine:** Godot 4.x  
**Language:** GDScript  
**Primary target:** Windows / Steam  
**Porting goal:** Console-ready architecture, with console work deferred until the PC game proves itself.  
**Gameplay:** 3D fixed-camera pinball roguelike.

## Core pitch

Paradigm is a run-based pinball roguelike where the player's table physically evolves during a run. The player begins with a simple machine and installs increasingly strange components, modifiers, ramps, hazards and synergistic systems as encounters are cleared.

The design goal is that the table itself becomes the player's build.

## Current milestone

The first milestone is a **physics spike**, not a content build.

Prove that this feels like pinball using an intentionally ugly greybox containing:

- one ball
- plunger / launch lane
- two independently controlled flippers
- slingshots
- three bumpers
- one elevated ramp
- walls
- drain

Do not build roguelike systems until ball/flipper interaction feels good enough to support the whole game.

## Controls (initial)

| Action | Keyboard | Controller |
|---|---|---|
| Left flipper | A | LB |
| Right flipper | D | RB |
| Launch | Space | A / Cross-equivalent |
| Nudge left | Q | TBD |
| Nudge right | E | TBD |
| Pause | Esc | Menu |

## Repository layout

- `assets/` - game art/audio/material assets
- `data/` - data-driven content definitions
- `docs/` - architecture, design, agent and QA documentation
- `scenes/` - Godot scenes
- `scripts/` - runtime code grouped by responsibility
- `tests/` - automated and deterministic validation
- `tools/` - development/debug utilities

## Development rules

Read `AGENTS.md` and the files in `docs/` before implementing a Jira ticket.
