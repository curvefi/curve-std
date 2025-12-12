from __future__ import annotations

import boa

from tests.unitary.ema.conftest import DUMMY_ALLOWED_EMAS
from tests.unitary.ema.helpers import reference_compute


def test_default_behavior_no_time_elapsed(ema):
    """Update should be a no-op if block.timestamp did not move."""
    ema_id = DUMMY_ALLOWED_EMAS[0]
    prev_value = 10**9
    ema.internal.setup(ema_id, prev_value, 42)

    before_slot = ema.emas(ema_id)
    result = ema.internal.update(ema_id, 5 * 10**9)

    after_slot = ema.emas(ema_id)
    assert result == prev_value
    assert after_slot.prev_value == prev_value
    assert after_slot.prev_timestamp == before_slot.prev_timestamp


def test_default_behavior_time_elapsed(ema):
    """Update should smooth the new value and persist it in storage."""
    ema_id = DUMMY_ALLOWED_EMAS[0]
    prev_value = 500_000
    new_value = 1_500_000
    ema_time = 20
    elapsed = 7

    ema.internal.setup(ema_id, prev_value, ema_time)
    boa.env.time_travel(elapsed)

    result = ema.internal.update(ema_id, new_value)
    expected = reference_compute(prev_value, new_value, ema_time, elapsed)

    slot = ema.emas(ema_id)
    assert result == expected
    assert slot.prev_value == expected
    assert slot.prev_timestamp == boa.env.timestamp


def test_ema_not_initialized(ema):
    """Calling update without setup should revert."""
    with boa.reverts(dev="ema not initialized"):
        ema.internal.update(DUMMY_ALLOWED_EMAS[0], 1)
