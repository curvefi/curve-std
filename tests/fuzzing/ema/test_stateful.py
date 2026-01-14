from __future__ import annotations

import boa
from hypothesis import settings, Phase
from hypothesis.stateful import RuleBasedStateMachine, rule, invariant, initialize
from hypothesis import strategies as st

from tests.unitary.ema.helpers import reference_compute
from tests.utils.deployers import EMA_DEPLOYER

MAX_VALUE = 2**128
TEST_EMA_ID = "fz00"


class EMAStateMachine(RuleBasedStateMachine):
    """Stateful fuzz test for EMA contract."""

    @initialize(
        initial_value=st.integers(min_value=0, max_value=MAX_VALUE),
        ema_time=st.integers(min_value=1, max_value=365 * 24 * 60 * 60),
    )
    def setup(self, initial_value, ema_time):
        self.ema = EMA_DEPLOYER.deploy([(TEST_EMA_ID, initial_value, ema_time)])
        self.ema_time = ema_time
        self.min_value_seen = initial_value
        self.max_value_seen = initial_value
        self.persisted_prev = initial_value
        self.persisted_queued = initial_value
        self.elapsed_time = 0
        self.last_update_time = 0

    @rule(new_value=st.integers(min_value=0, max_value=MAX_VALUE))
    def update(self, new_value):
        """Update the EMA with a new value."""
        dt = self.elapsed_time - self.last_update_time
        expected = reference_compute(self.persisted_prev, self.persisted_queued, self.ema_time, dt)
        returned = self.ema.internal.update(TEST_EMA_ID, new_value)
        assert returned == expected, f"update {returned} != expected {expected} for dt {dt}"
        self.persisted_prev = returned
        self.persisted_queued = new_value
        self.last_update_time = self.elapsed_time
        self.min_value_seen = min(self.min_value_seen, new_value)
        self.max_value_seen = max(self.max_value_seen, new_value)

    @rule(dt=st.integers(min_value=1, max_value=365 * 24 * 60 * 60))
    def time_travel(self, dt):
        """Advance time."""
        boa.env.time_travel(dt)
        self.elapsed_time += dt

    @invariant()
    def bounded_by_historical_extremes(self):
        """EMA should never exceed the range of values it has seen."""
        current = self.ema.internal.read(TEST_EMA_ID)
        assert current >= self.min_value_seen, f"EMA {current} below min seen {self.min_value_seen}"
        assert current <= self.max_value_seen, f"EMA {current} above max seen {self.max_value_seen}"

    @invariant()
    def no_overshoot(self):
        """EMA should always be between persisted prev and queued values."""
        current = self.ema.internal.read(TEST_EMA_ID)
        lower = min(self.persisted_prev, self.persisted_queued)
        upper = max(self.persisted_prev, self.persisted_queued)
        assert lower <= current <= upper, f"EMA {current} overshot bounds [{lower}, {upper}]"


    @invariant()
    def monotonic_convergence(self):
        """Between updates, EMA should move monotonically towards queued value."""
        current = self.ema.internal.read(TEST_EMA_ID)
        with boa.env.anchor():
            boa.env.time_travel(100)
            mid = self.ema.internal.read(TEST_EMA_ID)
            boa.env.time_travel(100)
            later = self.ema.internal.read(TEST_EMA_ID)

        # Check monotonic movement towards target
        if self.persisted_queued >= current:
            assert current <= mid <= later, "EMA not monotonically increasing towards target"
        else:
            assert current >= mid >= later, "EMA not monotonically decreasing towards target"

    @invariant()
    def eventual_convergence(self):
        """After sufficient time, EMA should be at (or near) queued value."""
        with boa.env.anchor():
            boa.env.time_travel(100 * self.ema_time)
            future = self.ema.internal.read(TEST_EMA_ID)

        gap = abs(future - self.persisted_queued)
        assert gap == 0, f"EMA {future} != {self.persisted_queued} within tolerance after 100x ema_time"


TestEMA = EMAStateMachine.TestCase
TestEMA.settings = settings(deadline=None, phases=[Phase.explicit, Phase.reuse, Phase.generate, Phase.target])
