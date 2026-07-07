# Computer-Use Smoke Test

## Purpose

This smoke test adds a real-window demo check on top of the headless validator.
It is intentionally bounded and verifies that the playable prototype launches,
core menu routes work, a run can start, basic combat responds, and the game can
return to menu cleanly.

## What It Checks

- Game launches in a real Godot window without crashing.
- Main menu appears at the expected `720x1280` resolution.
- `Start Run`, `Upgrades`, `Missions`, `Settings`, and `Validation` are reachable from the main menu.
- A run starts from `Start Run`.
- The squad responds to left/right pointer movement.
- Firing is visible in the current configured mode.
- Zombies appear during the run.
- Barricade UI responds and pause/unpause works.
- The run can return to the main menu through pause or end-screen UI.

## Runtime

- Target runtime: `3-8 minutes`
- Typical runtime: `4-5 minutes`

## Files

- Launcher: `project/tests/computer_use/run_computer_use_smoke_test.ps1`
- This guide: `project/tests/computer_use/computer_use_smoke_test.md`

## How To Run

1. Launch the real game window:

```powershell
powershell -ExecutionPolicy Bypass -File .\project\tests\computer_use\run_computer_use_smoke_test.ps1 -WaitForExit
```

2. If Godot is not installed at `C:\Users\scott\Desktop\Godot_v4.7-stable_win64.exe`, set `GODOT_EXE` first or pass `-GodotExe`.

3. Drive the window with Computer Use using the bounded flow below.

## Bounded Flow

1. Wait for the main menu title `Zombie Barricade Prototype` and the `Start Run` button.
2. Open `Upgrades`, confirm the screen title `Permanent Upgrades`, then click `Back`.
3. Open `Missions`, confirm the screen title `Missions`, then click `Back`.
4. Open `Settings`, confirm the screen title `Settings`, then click `Back`.
5. Open `Validation`, confirm the validation scene loads, then return to the main menu.
   Because the validation screen has no explicit menu button, close and relaunch the game after this check unless your automation can safely use an in-game quit path.
6. Relaunch the game if needed and click `Start Run`.
7. Confirm HUD text appears for `Distance`, `Squad`, `Coins`, `Wave`, `Objective`, `Barricade`, and `Weapon`.
8. Move the mouse left and right across the road and confirm the squad follows horizontally.
9. Confirm firing:
   - If the HUD weapon line ends with `| Auto`, wait for visible shots without holding input.
   - If `| Auto` is absent, hold left mouse button briefly and confirm visible shots.
10. Wait for enemies to spawn and confirm at least one zombie is visible or takes damage.
11. Press `B` once and confirm barricade UI changes or a status message appears.
12. Press `Escape`, confirm the pause menu appears, then choose `Resume`.
13. Press `Escape` again, choose `Menu`, and confirm the main menu returns.

## Pass Criteria

- The game window opens and stays responsive.
- The main menu renders with the expected buttons.
- `Upgrades`, `Missions`, `Settings`, and `Validation` can each be reached.
- `Start Run` transitions into gameplay.
- Squad movement and firing are visibly responsive.
- Enemies appear during the smoke run.
- Pause and return-to-menu work cleanly.

## Failure Criteria

Fail the smoke test if any of the following happens:

- The game does not launch.
- The main menu does not appear.
- `Start Run` cannot be clicked.
- Gameplay never starts.
- Squad movement does not respond.
- Firing is not visible in the expected fire mode.
- Enemies never appear.
- The game crashes, hangs, or cannot return to menu cleanly.

## Known Limitations

- This is a smoke test, not a full clear of every upgrade, mission, gate, or boss path.
- The validation scene is only a reachability check here; it is not a second replacement for headless validation.
- Visual confirmation of pickups and multi-gate rows may not occur in every short run because spawn timing is dynamic.
- If validation is opened from the main menu, the simplest bounded flow is to relaunch afterward instead of navigating deeper through validation UI.

## Stable UI Hints

- Expected window size: `720x1280`
- Main menu buttons are stacked vertically in this order:
  `Start Run`, `Upgrades`, `Missions`, `Settings`, `Validation`, `Quit`
- Settings screen contains `Screen Shake`, `Auto Fire`, `Hit Flash`, `SFX Volume`, and `Back`
- Pause menu contains `Resume` and `Menu`
- End screen contains `Replay`, `Upgrade`, and `Menu`

## Reporting Template

Record the result with:

- Launch: `pass` or `fail`
- Menu navigation: `pass` or `fail`
- Validation scene reachability: `pass` or `fail`
- Gameplay start: `pass` or `fail`
- Squad movement: `pass` or `fail`
- Firing: `pass` or `fail`
- Enemy visibility: `pass` or `fail`
- Pause/menu return: `pass` or `fail`
- Notes: short blockers, flake, or visual limitations
