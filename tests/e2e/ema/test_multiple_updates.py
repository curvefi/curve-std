from __future__ import annotations

import boa

from tests.unitary.ema.helpers import reference_compute
from tests.utils.deployers import EMA_DEPLOYER

EMA_ID = "e2e0"
EMA_TIME = 600
INITIAL_VALUE = 10**18


def test_only_last_update_matters():
    """Multiple updates in same block should only consider the last value."""
    ema = EMA_DEPLOYER.deploy([(EMA_ID, INITIAL_VALUE, EMA_TIME)])
    last_value = 5 * 10**18
    elapsed = 300

    # Perform multiple updates with different intermediate values
    for i in range(10):
        ema.internal.update(EMA_ID, i * 10**18)

    # Final update with our target value
    ema.internal.update(EMA_ID, last_value)

    # Time travel and read
    boa.env.time_travel(elapsed)
    result = ema.internal.read(EMA_ID)

    # Expected: EMA smoothing from initial_value toward last_value
    expected = reference_compute(INITIAL_VALUE, last_value, EMA_TIME, elapsed)
    assert result == expected
