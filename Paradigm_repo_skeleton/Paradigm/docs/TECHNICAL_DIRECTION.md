# Technical Direction

## Locked decisions

- **Engine:** Godot 4.x
- **Language:** GDScript
- **Gameplay:** 3D
- **Camera:** fixed / authored pinball perspective
- **Physics:** Godot 3D rigid-body simulation, tuned for game feel
- **Initial platform:** Windows / Steam
- **Input:** keyboard and controller from first playable
- **Art direction:** stylized 3D; final visual style remains open
- **Porting:** architecture must remain platform-independent where practical; console work is deferred

## Why 3D

Paradigm's core differentiator is the evolving physical machine. Real depth allows:

- elevated ramps and crossing lanes
- vertical table expansion
- physically installed upgrades
- stronger lighting/material response
- more expressive bosses and hazards
- readable visual evolution from simple table to chaotic machine

## First technical gate

The project does not proceed into full roguelike implementation until the greybox demonstrates satisfying:

- ball movement
- flipper timing
- bumper response
- ramp traversal
- drain behavior
- high-speed collision stability
