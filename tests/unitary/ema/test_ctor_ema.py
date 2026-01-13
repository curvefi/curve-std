from __future__ import annotations

from tests.utils.constants import MAX_EMAS
from tests.utils.deployers import EMA_DEPLOYER


def test_default_behavior():
    """Constructor should persist the allowed EMA ids as provided."""
    for size in range(MAX_EMAS + 1):
        allowed_ids = [f"e{index:03d}" for index in range(size)]
        # EMAConfig struct: (ema_id, initial_value, ema_time)
        configs = [
            (ema_id, (i + 1) * 10**18, (i + 1) * 600)
            for i, ema_id in enumerate(allowed_ids)
        ]
        ema = EMA_DEPLOYER.deploy(configs)
        observed = [ema.ALLOWED_EMAS(i) for i in range(size)]
        assert observed == allowed_ids
