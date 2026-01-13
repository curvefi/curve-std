from __future__ import annotations

import pytest

from tests.utils.deployers import EMA_DEPLOYER

DUMMY_ALLOWED_EMAS = ["ema0", "ema1", "ema2", "ema3", "ema4"]
# EMAConfig struct: (ema_id, initial_value, ema_time)
DUMMY_EMA_CONFIGS = [(ema_id, 10**18, 600) for ema_id in DUMMY_ALLOWED_EMAS]


@pytest.fixture
def ema():
    """Deploy an EMA contract seeded with predictable ids."""
    return EMA_DEPLOYER.deploy(DUMMY_EMA_CONFIGS)
