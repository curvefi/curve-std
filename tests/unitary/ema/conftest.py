from __future__ import annotations

import pytest

from tests.utils.deployers import EMA_DEPLOYER

DUMMY_ALLOWED_EMAS = ["ema0", "ema1", "ema2", "ema3", "ema4"]
# EMAConfig struct: (ema_id, initial_value, ema_time)
DUMMY_EMA_CONFIGS = [
    (ema_id, (i + 1) * 10**18, (i + 1) * 600)
    for i, ema_id in enumerate(DUMMY_ALLOWED_EMAS)
]


@pytest.fixture
def ema():
    """Deploy an EMA contract seeded with predictable ids."""
    return EMA_DEPLOYER.deploy(DUMMY_EMA_CONFIGS)
