from __future__ import annotations

import pytest

from tests.utils.deployers import EMA_DEPLOYER

DUMMY_ALLOWED_EMAS = ["ema0", "ema1", "ema2", "ema3", "ema4"]


@pytest.fixture
def ema():
    """Deploy an EMA contract seeded with predictable ids."""
    return EMA_DEPLOYER.deploy(DUMMY_ALLOWED_EMAS)
