import os
import shutil
from pathlib import Path

def perform_migration(from_dir: Path, to_dir: Path, force: bool = False) -> None:
    """Atomically migrate configuration files and hermes-home from from_dir to to_dir.
    
    If any error occurs during copy operations, the destination directory is rolled back
    to its clean, pre-migration state.
    
    Raises:
        FileNotFoundError: If the source directory from_dir does not exist.
        FileExistsError: If the destination directory is not empty and force is False.
    """
    from_dir = Path(from_dir).resolve()
    to_dir = Path(to_dir).resolve()
    
    if not from_dir.exists() or not from_dir.is_dir():
        raise FileNotFoundError(f"Source directory does not exist: {from_dir}")
        
    if to_dir.exists() and any(to_dir.iterdir()) and not force:
        raise FileExistsError(f"Destination directory is not empty: {to_dir}")
        
    created_paths = []
    
    try:
        # Walk recursively to find all files and directories
        for root, dirs, files in os.walk(from_dir):
            rel_path = Path(root).relative_to(from_dir)
            dest_parent = to_dir / rel_path
            
            # Replicate directories
            for d in dirs:
                dest_dir = dest_parent / d
                if not dest_dir.exists():
                    dest_dir.mkdir(parents=True, exist_ok=True)
                    created_paths.append(dest_dir)
                    
            # Replicate files preserving attributes
            for f in files:
                src_file = Path(root) / f
                dest_file = dest_parent / f
                
                # Make sure the parent folder exists
                if not dest_parent.exists():
                    dest_parent.mkdir(parents=True, exist_ok=True)
                    created_paths.append(dest_parent)
                    
                shutil.copy2(src_file, dest_file)
                created_paths.append(dest_file)
                
        # Write .metadata.json with the migration timestamp
        import json
        import datetime
        metadata_file = to_dir / ".metadata.json"
        metadata_data = {
            "migration_timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat()
        }
        with open(metadata_file, "w", encoding="utf-8") as f:
            json.dump(metadata_data, f)
        created_paths.append(metadata_file)
                
    except Exception as e:
        # Rollback: delete created files/directories in reverse order
        for path in reversed(created_paths):
            try:
                if path.is_file() or path.is_symlink():
                    path.unlink(missing_ok=True)
                elif path.is_dir():
                    shutil.rmtree(path, ignore_errors=True)
            except Exception:
                pass
        raise e

