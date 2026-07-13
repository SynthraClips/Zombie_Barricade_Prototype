# Project Location Migration Report

## Authoritative location

`G:\project\Small Game` contains the active `project.godot` and is the permanent project location.

## Old-location inspection

`C:\Users\scott\Documents\Small Game\project` was found to be an NTFS directory junction whose target is `G:\project\Small Game`, not an independent project copy. Consequently, every file visible through the old path is the same authoritative file; comparing or copying those entries as if they were two trees would be unsafe and could overwrite or delete the active project.

## Classification and actions

- Files merged: none; there was no separate old tree.
- Identical duplicates: all entries exposed through the junction are identical by definition because both paths resolve to the same files.
- Files deleted as obsolete: none from inside the junction.
- Files preserved for manual review: none.
- Conflicts: none.
- `migration_backup`: not created because no separate, uncertain, or non-identical files existed to preserve.
- Obsolete absolute runtime references removed: none were present. One historical test-result note mentions the old launch command; it is documentation, not a runtime dependency, and is retained as test history.
- Old project directory removed: yes. After the authoritative project passed its isolated 159-check Godot validation suite, the verified junction itself was removed non-recursively. No file beneath its G-drive target was deleted.
