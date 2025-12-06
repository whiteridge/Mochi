"""
Test configuration to ensure project root is on sys.path and heavy deps are stubbed.
"""
import sys
import types
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

# Stub dotenv to avoid filesystem access to .env during tests
if "dotenv" not in sys.modules:
    dotenv_stub = types.ModuleType("dotenv")

    def _noop_load_dotenv(*args, **kwargs):
        return False

    dotenv_stub.load_dotenv = _noop_load_dotenv
    sys.modules["dotenv"] = dotenv_stub

    main_stub = types.ModuleType("dotenv.main")
    main_stub.load_dotenv = _noop_load_dotenv
    sys.modules["dotenv.main"] = main_stub

# Stub composio to avoid importing network-bound dependencies during tests
if "composio" not in sys.modules:
    composio_stub = types.ModuleType("composio")

    class DummyComposio:
        def __init__(self, *args, **kwargs):
            self.tools = types.SimpleNamespace(get=lambda *a, **k: [], execute=lambda *a, **k: {})

    composio_stub.Composio = DummyComposio
    sys.modules["composio"] = composio_stub

    exceptions_stub = types.ModuleType("composio.exceptions")

    class EnumMetadataNotFound(Exception):
        """Stubbed exception placeholder."""

    exceptions_stub.EnumMetadataNotFound = EnumMetadataNotFound
    sys.modules["composio.exceptions"] = exceptions_stub

