import os
import shutil
import tempfile
from pathlib import Path
import pytest
from unittest import mock

# ─── Path Resolution Tests ───

def test_hermes_home_honor_explicit_hermes_home(monkeypatch):
    """If both HERMES_HOME and HERMES_USERDATA are set, HERMES_HOME must take precedence."""
    with tempfile.TemporaryDirectory() as tmp1, tempfile.TemporaryDirectory() as tmp2:
        monkeypatch.setenv("HERMES_HOME", tmp1)
        monkeypatch.setenv("HERMES_USERDATA", tmp2)
        
        from hermes_constants import _hermes_home_from_env
        resolved = _hermes_home_from_env()
        assert resolved == Path(tmp1)

def test_hermes_home_fallback_to_userdata(monkeypatch):
    """If HERMES_HOME is unset but HERMES_USERDATA is set, HERMES_HOME must default to HERMES_USERDATA/hermes-home."""
    monkeypatch.delenv("HERMES_HOME", raising=False)
    with tempfile.TemporaryDirectory() as tmpdir:
        monkeypatch.setenv("HERMES_USERDATA", tmpdir)
        
        from hermes_constants import _hermes_home_from_env
        resolved = _hermes_home_from_env()
        assert resolved == Path(tmpdir) / "hermes-home"

def test_hermes_home_normalization(monkeypatch):
    """Paths must be fully normalized even if relative paths are passed in HERMES_USERDATA."""
    monkeypatch.delenv("HERMES_HOME", raising=False)
    relative_path = "./custom_test_dir_relative"
    monkeypatch.setenv("HERMES_USERDATA", relative_path)
    
    from hermes_constants import _hermes_home_from_env
    resolved = _hermes_home_from_env()
    assert resolved.is_absolute()
    assert resolved == Path(relative_path).resolve() / "hermes-home"


# ─── Migration Utility Tests ───

def test_migration_source_missing():
    """Migration must raise FileNotFoundError if the source directory does not exist."""
    try:
        from hermes_cli.migrate import perform_migration
    except ImportError:
        pytest.fail("Migration module 'hermes_cli.migrate' not implemented yet")
        
    with tempfile.TemporaryDirectory() as dest_dir:
        non_existent_src = Path(dest_dir) / "non_existent_folder"
        with pytest.raises(FileNotFoundError):
            perform_migration(from_dir=non_existent_src, to_dir=Path(dest_dir))

def test_migration_atomic_success():
    """Migration must atomically copy configurations and the nested hermes-home folder, maintaining attributes."""
    try:
        from hermes_cli.migrate import perform_migration
    except ImportError:
        pytest.fail("Migration module 'hermes_cli.migrate' not implemented yet")

    with tempfile.TemporaryDirectory() as src_dir, tempfile.TemporaryDirectory() as dest_dir:
        src = Path(src_dir)
        dest = Path(dest_dir)
        
        # Setup source files
        (src / "connection.json").write_text('{"platform": "wechat"}', encoding="utf-8")
        (src / "window-state.json").write_text('{"width": 1024, "height": 768}', encoding="utf-8")
        (src / "hermes-home").mkdir()
        (src / "hermes-home" / "session.db").write_text("sqlite db content", encoding="utf-8")
        (src / "hermes-home" / "skills.lock").write_text("locked", encoding="utf-8")
        
        # Trigger migration
        perform_migration(from_dir=src, to_dir=dest)
        
        # Assertions
        assert (dest / "connection.json").exists()
        assert (dest / "window-state.json").exists()
        assert (dest / "hermes-home" / "session.db").exists()
        assert (dest / "hermes-home" / "skills.lock").exists()
        
        assert (dest / "connection.json").read_text(encoding="utf-8") == '{"platform": "wechat"}'
        assert (dest / "hermes-home" / "session.db").read_text(encoding="utf-8") == "sqlite db content"

def test_migration_atomic_rollback():
    """If copy fails halfway, migration must completely roll back and restore the destination to its clean state."""
    try:
        from hermes_cli.migrate import perform_migration
    except ImportError:
        pytest.fail("Migration module 'hermes_cli.migrate' not implemented yet")

    with tempfile.TemporaryDirectory() as src_dir, tempfile.TemporaryDirectory() as dest_dir:
        src = Path(src_dir)
        dest = Path(dest_dir)
        
        # Setup source files
        (src / "connection.json").write_text('{"platform": "whatsapp"}', encoding="utf-8")
        (src / "hermes-home").mkdir()
        (src / "hermes-home" / "session.db").write_text("sqlite database", encoding="utf-8")
        
        original_copy = shutil.copy2
        
        # Mock copy to raise an exception specifically during the nested DB copy
        def faulty_copy(s, d):
            if "session.db" in str(s):
                raise IOError("Disk full or permission denied")
            return original_copy(s, d)
            
        with mock.patch("shutil.copy2", side_effect=faulty_copy):
            with pytest.raises(IOError):
                perform_migration(from_dir=src, to_dir=dest)

                
        # Assertions: Verify rollback has occurred. Destination must be cleaned.
        assert not (dest / "connection.json").exists()
        assert not (dest / "hermes-home" / "session.db").exists()
        assert not (dest / "hermes-home").exists()
        
        # Ensure the destination directory itself, if it was created, is clean
        dest_contents = list(dest.glob("*"))
        assert len(dest_contents) == 0

def test_migration_destination_not_empty_refusal():
    """Migration must raise FileExistsError if the destination directory is not empty and force=False."""
    try:
        from hermes_cli.migrate import perform_migration
    except ImportError:
        pytest.fail("Migration module 'hermes_cli.migrate' not implemented yet")

    with tempfile.TemporaryDirectory() as src_dir, tempfile.TemporaryDirectory() as dest_dir:
        src = Path(src_dir)
        dest = Path(dest_dir)
        
        # Setup source and dummy destination files
        (src / "connection.json").write_text('{"platform": "whatsapp"}', encoding="utf-8")
        (dest / "stray_file.txt").write_text("existing content", encoding="utf-8")
        
        with pytest.raises(FileExistsError):
            perform_migration(from_dir=src, to_dir=dest, force=False)
            
        # Verify destination stray file is untouched and source is not copied
        assert (dest / "stray_file.txt").exists()
        assert not (dest / "connection.json").exists()

def test_migration_destination_not_empty_force():
    """Migration must overwrite and succeed if the destination directory is not empty and force=True."""
    try:
        from hermes_cli.migrate import perform_migration
    except ImportError:
        pytest.fail("Migration module 'hermes_cli.migrate' not implemented yet")

    with tempfile.TemporaryDirectory() as src_dir, tempfile.TemporaryDirectory() as dest_dir:
        src = Path(src_dir)
        dest = Path(dest_dir)
        
        # Setup source and dummy destination files
        (src / "connection.json").write_text('{"platform": "telegram"}', encoding="utf-8")
        (dest / "stray_file.txt").write_text("existing content", encoding="utf-8")
        
        # Proceed with force=True
        perform_migration(from_dir=src, to_dir=dest, force=True)
        
        # Verify both files are in the destination
        assert (dest / "connection.json").exists()
        assert (dest / "stray_file.txt").exists()

