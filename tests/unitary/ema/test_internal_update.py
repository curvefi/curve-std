from __future__ import annotations

import boa

from tests.unitary.ema.conftest import DUMMY_EMA_CONFIGS
from tests.unitary.ema.helpers import reference_compute


def test_default_behavior(ema):
    """Update should smooth the new value and persist it in storage."""
    ema_id, initial_value, ema_time = DUMMY_EMA_CONFIGS[0]
    new_value = 5 * 10**18
    elapsed = 7

    boa.env.time_travel(elapsed)

    result = ema.internal.update(ema_id, new_value)
    expected = reference_compute(initial_value, initial_value, ema_time, elapsed)

    slot = ema.eval(f"self._emas['{ema_id}']")
    assert result == expected
    assert slot.prev_value == expected
    assert slot.prev_timestamp == boa.env.timestamp
