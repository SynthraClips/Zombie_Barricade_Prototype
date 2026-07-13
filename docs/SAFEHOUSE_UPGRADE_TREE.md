# Safehouse Upgrade Tree

The Safehouse Upgrade Tree is the permanent progression screen opened from the main menu. Yggdrasil supplies the runtime graph, connections, camera, and node surface; Small Game remains authoritative for costs, currency, ownership, effects, migration, and saving.

## Integration map

```text
UpgradeScreen.tscn / UpgradeScreen.gd
  -> YggdrasilLoader.load_tree("Small Game/Safehouse Upgrade Tree")
  -> res://yggdrasil/Small Game/safehouse_upgrade_tree.tres
  -> UpgradeManager.gd transaction and progression queries
  -> SaveManager.gd save_data.json
  -> existing gameplay consumers
```

Key files:

- `data/safehouse_upgrade_tree.json`: 25 stable-ID nodes, branches, costs, prerequisites, and effects.
- `yggdrasil/registry.tres`: editor-visible Yggdrasil registry.
- `yggdrasil/Small Game/small_game.tres`: registered project group.
- `yggdrasil/Small Game/safehouse_upgrade_tree.tres`: editable topology, positions, connections, root, attributes, and tree visuals.
- `scripts/upgrades/SafehouseUpgradeTree.gd`: definition validator.
- `scripts/upgrades/UpgradeManager.gd`: ownership, purchases, legacy synchronization, and modifier API.
- `scripts/core/SaveManager.gd`: versioned project save and pre-migration backup.
- `scripts/ui/UpgradeScreen.gd`: project-owned Yggdrasil adapter/controller.
- `scenes/ui/SafehouseTreeNode.tscn` and `SafehouseTreeConnection.tscn`: themed project visuals.
- `tests/safehouse_upgrade_tree_tests.gd`: definition, transaction, migration, effect, and UI coverage.

Existing consumers remain responsible for gameplay: `WeaponManager`, `SquadManager`, `Barricade`, `BarricadeManager`, `RunManager`, `RewardPickup`, `ArmouryCacheManager`, and `GameManager` query `UpgradeManager`. Temporary reward boosts remain run state and are never written to permanent ownership.

## Stable IDs and migration

`permanent_upgrade_ids` in `user://save_data.json` stores IDs such as `arsenal_rifle_damage_01`. Display names, Yggdrasil numeric IDs, and positions are never save identifiers. Unknown IDs are retained and logged.

The immutable ID is duplicated into each node's `stable_upgrade_id` attribute and is always read from that attribute first. Yggdrasil may rewrite `external_id` to the editor-facing node ID during save, so project behavior must never treat `external_id` as authoritative after an editor round trip.

Save version 4 adds `permanent_upgrade_ids: Array[String]` and `upgrade_tree_version: int`. Legacy `upgrades` levels and `upgrade_choices` are preserved. On load, `legacy_ids` map old ownership into stable nodes; higher old ranks keep their full aggregate effect. Before an older valid save is migrated, SaveManager writes `save_data_corrupt_pre_migration_v<version>_<timestamp>.json`.

## Adding an upgrade

1. Add an object to `data/safehouse_upgrade_tree.json` with a unique permanent `id`.
2. Choose `Arsenal`, `Squad`, `Barricade`, `Logistics`, or `Heroes`.
3. Set a non-negative cost, valid prerequisites, recognized effect type/value, and `enabled` flag.
4. Add an old aggregate ID to `legacy_ids` only if no other node claims it.
5. For a new effect type, register it in `SafehouseUpgradeTree.VALID_EFFECT_TYPES`, add its aggregate definition to `data/upgrades.json`, and expose it through `UpgradeManager`.
6. Connect gameplay with `get_upgrade_value()` or `get_choice_value()`; do not scatter owned-ID checks.
7. Run the dedicated and existing validation suites, then inspect the smallest supported resolution.

Create the matching Yggdrasil node in the editor, set its `stable_upgrade_id` attribute, and connect its prerequisite nodes. Runtime validation rejects missing, duplicate, unknown, or mismatched topology. The editor resource owns layout and connections; the JSON file owns gameplay prerequisites and balance.

## Editor workflow

Open the **Yggdrasil** tab, expand **Small Game**, and double-click **Safehouse Upgrade Tree**. Moving nodes and saving updates `res://yggdrasil/Small Game/safehouse_upgrade_tree.tres`; runtime loads that same resource. Player ownership is never serialized by the editor resource.

The original runtime topology was migrated once with `res://tests/MigrateSafehouseTreeResource.tscn`, implemented by `SafehouseTreeResourceMigration.gd`. The utility is explicit and refuses to overwrite a populated tree unless Godot is launched with the user argument `--confirm-yggdrasil-migration-overwrite`. It never runs during game or editor startup.

The migration assigns persistent Godot resource UIDs to the registry, group, and tree after saving them. Yggdrasil uses those UIDs when opening browser entries, so removing them can leave the names visible in the registry while preventing the tree from opening in the editor.

## Purchase flow

The UI requires confirmation. `purchase_tree_upgrade()` rechecks state, ownership, prerequisites, and funds; snapshots save data; deducts once; adds the stable ID; updates the compatible legacy aggregate; and saves once. Failed writes restore the snapshot. `purchase_in_progress` rejects repeated confirmation. Refund and respec are intentionally unavailable.

## Validation and reset

Run `res://tests/SafehouseUpgradeTreeTests.tscn` headlessly. It covers invalid definitions, purchases, duplicate input, save/reload, migration, idempotence, five effect categories, scene construction, and all 25 nodes. Also run the existing validation harness.

There is no player reset. Isolated tests may snapshot `SaveManager.save_data`, replace it with `_default_save_data()`, and restore it afterward. Manual deletion of `user://save_data.json` is only for a disposable developer profile.

## Addon version

Yggdrasil **v2.3.0**, upstream commit `8d00b89aeb4a62a0d33b17eee936ca2a21216282`, is installed under `addons/yggdrasil`. The plugin and its official loader/serializer autoloads are enabled in `project.godot`. Project behavior stays outside the addon.
