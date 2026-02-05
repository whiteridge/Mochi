import os


def pytest_configure() -> None:
    os.environ.setdefault("COMPOSIO_CACHE_DIR", "/tmp/composio-cache")
