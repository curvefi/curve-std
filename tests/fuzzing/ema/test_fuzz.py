from __future__ import annotations

import math

import boa
import pytest
from hypothesis import given, settings, strategies as st

from tests.utils.deployers import EMA_DEPLOYER

TEST_EMA_ID = "fz00"


def _float_reference(prev_value: int, new_value: int, ema_time: int, dt: int) -> float:
    if dt == 0:
        return float(prev_value)
    weight = math.exp(-dt / ema_time)
    return prev_value * weight + new_value * (1 - weight)


def _deploy_ema():
    return EMA_DEPLOYER.deploy([TEST_EMA_ID])


@given(
    prev_value=st.integers(min_value=0, max_value=10**20),
    new_value=st.integers(min_value=0, max_value=10**20),
    ema_time=st.integers(min_value=1, max_value=365 * 24 * 60 * 60),
    dt=st.integers(min_value=0, max_value=365 * 24 * 60 * 60),
)
@settings(max_examples=200, deadline=None)
def test_compute_matches_float_reference(prev_value, new_value, ema_time, dt):
    with boa.env.anchor():
        ema = _deploy_ema()
        ema.internal.setup(TEST_EMA_ID, prev_value, ema_time)
        if dt:
            boa.env.time_travel(dt)
        observed = ema.internal.compute(TEST_EMA_ID, new_value)

    expected = _float_reference(prev_value, new_value, ema_time, dt)
    tolerance = max(1.0, abs(expected) * 1e-9)
    assert observed == pytest.approx(expected, rel=1e-6, abs=tolerance)
