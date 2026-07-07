# Computer-Use Smoke Test Result

- Command used: `"C:\Users\scott\Desktop\Godot_v4.7-stable_win64.exe" --path "C:\Users\scott\Documents\Small Game\project"`
- Launch script: `project/tests/computer_use/run_computer_use_smoke_test.ps1`
- Launch log: `project/tests/computer_use/logs/launch_2026-07-07_11-39-57.log`
- Stdout log: `project/tests/computer_use/logs/godot_stdout_2026-07-07_11-39-57.log`
- Stderr log: `project/tests/computer_use/logs/godot_stderr_2026-07-07_11-39-57.log`
- Result: `partial`
- Headless validation: `pass (63 passed, 0 failed)` from `project/reports/prototype_validation_report.md` dated `2026-07-07T11:38:01`

## Checks Passed

- Game launched in the real Godot desktop window.
- Main menu appeared.
- `Start Run` was visible and clickable.
- `Upgrades` opened and returned.
- `Missions` opened and returned.
- `Settings` opened and returned.
- Gameplay started from `Start Run`.
- Squad/player appeared.
- Squad moved left and right in response to pointer input.
- Firing worked in the current configured fire mode.
  The HUD showed `Weapon: Rifle | Auto` and visible projectile fire was present during the run.
- Enemies appeared.
  Visible examples during the bounded run included `Walker`, `Runner`, and `Spitter`.
- Barricade UI responded.
  The HUD showed barricade state and HP updates during gameplay.
- Gate rows were visible during the bounded run.
- Pickups/rewards were collected during the bounded run.
  Stdout log confirms reward collection for coins and a damage boost.
- The game window closed cleanly at the end of the smoke run.

## Checks Not Reached Or Not Fully Confirmed

- Choosing one gate clears the row: not cleanly verified in the bounded smoke window.
- Pickup magnet behavior: reward collection was confirmed, but the magnet pull was not clearly isolated visually during this short run.
- In-game return to menu via the end-screen buttons was not reliably actuated by Computer Use during this run.
  This did not block the bounded smoke test because the window still closed cleanly.

## Bugs Found

- No new gameplay or startup bug was found during this smoke run.
- Automation note: end-screen button interaction was flaky under Computer Use in this run, but this was not investigated as a gameplay/system change because the requested bounded smoke scope was otherwise satisfied.
