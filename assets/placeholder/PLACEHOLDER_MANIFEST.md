# Placeholder Asset Manifest

The project currently renders most prototype visuals with Godot drawing primitives rather than image files. Replacing these entries requires editing the named script or scene; there were no active placeholder image files to move when this manifest was created. The integrated `goblin_normal` walker is production artwork and is intentionally excluded.

| Placeholder | Current location | Represents / used by | Recommended replacement | Animation | Replacement scope |
| --- | --- | --- | --- | --- | --- |
| Soldier and role variants | `scripts/gameplay/Soldier.gd::_draw` | Squad members in `Soldier.tscn` | Directional sprite sheet, about 64×96 px per frame | Idle, walk, fire; optional hit/death | Code/scene change required |
| Special enemies | `scripts/enemies/Enemy.gd::_draw` | Runner, dog, crawler, screamer, grabber, tank, brute, exploder, spitter, treasure horde, armoured walker, boss | Per-type transparent sheets, about 96×96 px; boss about 160×160 px | Walk, attack, hit, death; type-specific special | Code/scene change required |
| Barricades | `scripts/barricades/Barricade.gd::_draw` | Active barricade tiers | Wide transparent sprites, about 512×128 px | Damage states; optional deploy | Code/scene change required |
| Projectiles and weapon VFX | `scripts/weapons/Projectile.gd::_draw` and `scripts/ui/UIManager.gd` trail/explosion helpers | Bullets, rockets, flame, Tesla arc, impacts | 32–128 px projectile/VFX sheets or GPU particles | Travel, impact, loop where applicable | Code/scene change required |
| Reward pickups | `scripts/rewards/RewardPickup.gd::_draw` | Coins, soldiers, weapons, boosts, ammo | Individual 64×64 px icons | Pulse/collect optional | Code/scene change required |
| Gates | `scripts/gameplay/Gate.gd::_draw` | Mathematical choice gates | Wide gate art, about 192×192 px | Pulse/open/break optional | Code/scene change required |
| Road obstacles | `scripts/gameplay/Obstacle.gd::_draw` | Crates, vehicles, hazards and timed road objects | Per-type 128×128 px transparent art | Damage/destruction; hazard loop | Code/scene change required |
| Armoury cache | `scripts/gameplay/ArmouryCache.gd::_draw` | Timed weapon/ammo cache | About 128×128 px transparent sprite | Idle/glow, damage, open | Code/scene change required |
| Survivor rescue | `scripts/gameplay/SurvivorRescue.gd::_draw` | Rescue encounter and survivors | About 192×128 px transparent scene | Idle, damage, rescued/failed | Code/scene change required |
| Road and environment | `scripts/gameplay/Road.gd::_draw` | Battlefield background, road edges, lane markings | Seamless vertical environment layers, designed for 720×1280 portrait and stretchable aspect ratios | Scrolling layers optional | Code/scene change required |
| Main-menu backdrop figures | `scripts/ui/MainMenu.gd::_draw` | Menu environment, soldiers and enemies | 720×1280 scalable background plus separate character layers | Ambient loops optional | Code/scene change required |
| UI hit/muzzle flashes | `scenes/ui/UI.tscn`, `scripts/ui/UIManager.gd`, `scripts/gameplay/Soldier.gd::_draw` | Feedback overlays and flashes | Full-screen overlay/particle textures | Short one-shot | Scene/code change required |
| Generic screen backdrops | `scenes/main/MainMenu.tscn`, `scenes/ui/MissionScreen.tscn`, `scenes/ui/SettingsScreen.tscn`, `scenes/ui/UpgradeScreen.tscn` | Flat `ColorRect` prototype backgrounds | Scalable 9-slice panels or aspect-safe backgrounds | None required | Scene/theme change required |

Pixel-art replacements should use nearest-neighbour filtering and no mipmaps. File-only replacement is not currently sufficient for any entry above because the active placeholders are generated in code or are Godot primitives.
