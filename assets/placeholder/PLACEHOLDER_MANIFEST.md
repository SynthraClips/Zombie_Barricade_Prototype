# Placeholder Asset Manifest

The project uses replaceable SVG placeholders for the expansion content and retains drawing primitives as runtime fallbacks. The integrated `goblin_normal` walker is existing artwork and is intentionally excluded. Data files point to these placeholders so final art can replace the files without gameplay-code changes.

## Expansion placeholder folders

| Folder | Expected source size | Orientation / frames | Runtime contract |
| --- | --- | --- | --- |
| `weapons/` | 96×48 | Weapon faces right; one static frame | Paths are stored in `data/weapons.json`; used by Pickups and weapon Gates |
| `heroes/` | 72×96 | Character faces up-road; static fallback, future `idle`, `attack`, `ultimate` hooks | Paths are stored in hero definitions in `data/game_config.json` |
| `enemies/animals/` | 64×48 or 64×56 | Faces down-road; future `move`, `attack`, `hit`, `death` hooks | Paths are stored in `data/enemies.json` |
| `bosses/` | 96×96 | Faces down-road; future `move`, `attack`, `phase`, `hit`, `death` hooks | One descriptive placeholder per boss archetype |
| `buildings/` | 160×120 | Front/road-facing, single frame; optional night-lit variant | Paths are stored in `data/environments.json` |
| `pickups/` | 64×64 | Single readable icon; optional `pulse`, `collect` animation | Tesla Ammo Cache is distinct from temporary Ammo effects |
| `night/` | 64×128 or seamless portrait layers | Upright environmental lighting | Used as replaceable night-light/environment references |

Keep transparent backgrounds, preserve filenames, and use Godot's default SVG import. Animated replacements should keep the listed animation names even when their frame counts differ.

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

Pixel-art replacements should use nearest-neighbour filtering and no mipmaps. Legacy primitive entries still require scene integration; expansion placeholders are already data-addressable.
