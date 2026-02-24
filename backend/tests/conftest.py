"""Pytest configuration for the MotoMuse backend test suite."""

import sys
from pathlib import Path

# Ensure the backend package root is on the path so tests can import
# modules directly (e.g. `import bike_vision`) without a package prefix.
sys.path.insert(0, str(Path(__file__).parent.parent))
