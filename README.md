# Sameduck Battle Simulator

A [Totally Accurate Battle Simulator](https://store.steampowered.com/app/508440/)-style
game built in **Godot 4.6.3**. Deploy a budget-limited army of wobbly
**active-ragdoll** units, then watch two physics-driven hosts brawl it out
under fully autonomous AI.

![icon](icon.svg)

## Features

- **3D active-ragdoll units** — each fighter is a self-balancing `RigidBody3D`
  (a PD controller keeps it upright, so it wobbles, staggers from knockbacks,
  and collapses into a limp ragdoll on death) with joint-connected dangling
  arms for extra TABS-style flailing.
- **7 unit types** — Peasant, Spearman, Brawler, Archer, Knight, Bomber and a
  hulking Giant, each with distinct cost, health, reach, speed, knockback and
  melee/ranged behaviour (including homing arrows and AoE bombs).
- **Campaign** — 6 hand-tuned battles of escalating difficulty. Win to unlock
  the next battle and new units. Progress is saved automatically.
- **Sandbox** — unlimited budget; place either team anywhere and experiment.
- **Deployment phase** — spend gold to position your army on your half of the
  field, then hit *Start Battle*.
- **RTS camera** — WASD/arrows pan, Q/E rotate, mouse wheel zoom.

## Controls

| Action | Input |
| --- | --- |
| Deploy selected unit | Left-click on your (blue) half |
| Remove a unit (refunds gold) | Right-click near it |
| Pan camera | `W` `A` `S` `D` / arrow keys |
| Rotate camera | `Q` / `E` |
| Zoom | Mouse wheel (or `+` / `-`) |

## Running

Open the project folder in **Godot 4.6.3** and press **Play** (F5), or from a
command line:

```sh
godot --path . 
```

## Project layout

```
project.godot              # project config + autoloads
scenes/Main.tscn           # entry scene (thin bootstrap)
scripts/
  Main.gd                  # builds the arena & UI per game state
  game/GameManager.gd      # global state machine (autoload)
  data/
    UnitDatabase.gd        # unit stat definitions (autoload)
    LevelDatabase.gd       # campaign levels (autoload)
    SaveManager.gd         # unlock/progress persistence (autoload)
  units/
    Unit.gd                # active-ragdoll fighter (build + AI + combat)
    Projectile.gd          # arrows / bombs
  world/Arena.gd           # battlefield, placement, simulation, win check
  camera/RTSCamera.gd      # RTS-style camera rig
  ui/                      # menus & HUDs (built in code)
```

Almost everything (meshes, bodies, joints, UI) is constructed in code rather
than authored as `.tscn` scenes — this keeps the project compact and easy to
extend.

## Extending

- **Add a unit:** add an entry in `UnitDatabase._ready()`. Set `unlocked: true`
  to make it available from the start, or list its id as a level `reward`.
- **Add a level:** append a dictionary to `LevelDatabase._ready()`.
- **Tune the ragdoll feel:** see `BALANCE_STIFFNESS`, `BALANCE_DAMPING` and
  `MOVE_FORCE` constants in `Unit.gd`.

## Tech notes

The build was validated headless against Godot 4.6.3 (`--headless --import`
plus an automated `--autobattle` smoke test that spawns two armies, runs the
full simulation, and asserts the battle resolves).

> Naming nod: it's *Sameduck* — close enough to the real thing.
