import fnmatch
from datetime import datetime
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

# =========================
# CONFIG
# =========================

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent

EXPORT_ROOT = PROJECT_ROOT / "exports"

PROJECT_NAME = "Small_Game_light_codebase"

# File types to include
INCLUDE_EXTENSIONS = {
    ".gd",
    ".tscn",
    ".tres",
    ".json",
    ".cfg",
    ".md",
    ".txt",
    ".godot",
    ".import",  # optional, useful sometimes for Godot asset references
}

# Specific files to include even if extension rules miss them
INCLUDE_FILENAMES = {
    "project.godot",
    "README.md",
}

# Folders to skip completely
EXCLUDE_DIRS = {
    ".godot",
    ".git",
    ".vscode",
    ".idea",
    "__pycache__",
    "builds",
    "exports",
    "screenshots",
    "recordings",
    "captures",
    "cache",
    "tmp",
    "temp",
    "logs",
}

# Heavy/non-essential file types to skip
EXCLUDE_EXTENSIONS = {
    ".png",
    ".jpg",
    ".jpeg",
    ".webp",
    ".gif",
    ".bmp",
    ".svg",
    ".mp3",
    ".wav",
    ".ogg",
    ".mp4",
    ".mov",
    ".avi",
    ".mkv",
    ".exe",
    ".dll",
    ".pck",
    ".zip",
    ".7z",
    ".rar",
    ".blend",
    ".psd",
}

# Optional: skip specific filename patterns
EXCLUDE_PATTERNS = {
    "*.uid",
    "*.tmp",
    "*.bak",
    "*.log",
}


# =========================
# EXPORT LOGIC
# =========================

def should_skip_path(path: Path) -> bool:
    parts = set(path.parts)

    if any(excluded in parts for excluded in EXCLUDE_DIRS):
        return True

    if path.suffix.lower() in EXCLUDE_EXTENSIONS:
        return True

    for pattern in EXCLUDE_PATTERNS:
        if fnmatch.fnmatch(path.name, pattern):
            return True

    return False


def should_include_file(path: Path) -> bool:
    if path.name in INCLUDE_FILENAMES:
        return True

    if path.suffix.lower() in INCLUDE_EXTENSIONS:
        return True

    return False


def export_codebase():
    if not PROJECT_ROOT.exists():
        raise FileNotFoundError(f"Project root does not exist: {PROJECT_ROOT}")

    EXPORT_ROOT.mkdir(parents=True, exist_ok=True)

    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    zip_path = EXPORT_ROOT / f"{PROJECT_NAME}_{timestamp}.zip"

    included_files = []
    skipped_files = []

    for path in PROJECT_ROOT.rglob("*"):
        if path.is_dir():
            continue

        if should_skip_path(path):
            skipped_files.append(path)
            continue

        if should_include_file(path):
            included_files.append(path)
        else:
            skipped_files.append(path)

    with ZipFile(zip_path, "w", compression=ZIP_DEFLATED) as zipf:
        for file_path in included_files:
            relative_path = file_path.relative_to(PROJECT_ROOT)
            zipf.write(file_path, relative_path)

        # Add a small export manifest
        manifest = [
            f"Project export: {PROJECT_NAME}",
            f"Created: {datetime.now().isoformat(timespec='seconds')}",
            f"Project root: {PROJECT_ROOT}",
            "",
            f"Included files: {len(included_files)}",
            f"Skipped files: {len(skipped_files)}",
            "",
            "Included file list:",
            *[str(p.relative_to(PROJECT_ROOT)) for p in included_files],
        ]

        zipf.writestr("_EXPORT_MANIFEST.txt", "\n".join(manifest))

    print()
    print("Light codebase export complete.")
    print(f"Created: {zip_path}")
    print(f"Included files: {len(included_files)}")
    print(f"Skipped files: {len(skipped_files)}")
    print()

    return zip_path


if __name__ == "__main__":
    export_codebase()
