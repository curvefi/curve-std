from __future__ import annotations

import boa

from tests.unitary.ema.conftest import DUMMY_EMA_CONFIGS
from tests.unitary.ema.helpers import reference_compute


def test_default_behavior_no_time_elapsed(ema):
    """When no time has passed the previous value is returned."""
    ema_id, initial_value, _ = DUMMY_EMA_CONFIGS[0]
    assert ema.internal.read(ema_id) == initial_value


def test_default_behavior_time_elapsed(ema):
    """EMA output should match the Python reference implementation."""
    ema_id, initial_value, ema_time = DUMMY_EMA_CONFIGS[0]
    elapsed = 9

    boa.env.time_travel(elapsed)

    observed = ema.internal.read(ema_id)
    # queued_value equals initial_value at start
    expected = reference_compute(initial_value, initial_value, ema_time, elapsed)
    assert observed == expected


def test_ema_not_allowed(ema):
    """Reading a non-whitelisted id should revert."""
    with boa.reverts(dev="id not allowed"):
        ema.internal.read("nope")
