from __future__ import annotations

import boa

from tests.unitary.ema.conftest import DUMMY_ALLOWED_EMAS
from tests.unitary.ema.helpers import reference_compute


def test_default_behavior_no_time_elapsed(ema):
    """When no time has passed the previous value is returned."""
    ema_id = DUMMY_ALLOWED_EMAS[0]
    ema.internal.setup(ema_id, 1234, 10)

    assert ema.internal.compute(ema_id, 9999) == 1234


def test_default_behavior_time_elapsed(ema):
    """EMA output should match the Python reference implementation."""
    ema_id = DUMMY_ALLOWED_EMAS[0]
    prev_value = 1_000_000
    new_value = 2_000_000
    ema_time = 30
    elapsed = 9

    ema.internal.setup(ema_id, prev_value, ema_time)
    boa.env.time_travel(elapsed)

    observed = ema.internal.compute(ema_id, new_value)
    expected = reference_compute(prev_value, new_value, ema_time, elapsed)
    assert observed == expected


def test_ema_not_initialized(ema):
    """Computing without a setup should revert with the proper dev string."""
    with boa.reverts(dev="ema not initialized"):
        ema.internal.compute(DUMMY_ALLOWED_EMAS[0], 1)
