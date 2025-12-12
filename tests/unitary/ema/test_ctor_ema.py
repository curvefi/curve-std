from __future__ import annotations

from tests.utils.constants import MAX_EMAS
from tests.utils.deployers import EMA_DEPLOYER


def test_default_behavior():
    """Constructor should persist the allowed EMA ids as provided."""
    for size in range(MAX_EMAS + 1):
        allowed = [f"e{index:03d}" for index in range(size)]
        ema = EMA_DEPLOYER.deploy(allowed)
        observed = [ema.ALLOWED_EMAS(i) for i in range(size)]
        assert observed == allowed
