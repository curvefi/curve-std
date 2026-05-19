import boa
from hypothesis import Phase, settings
from hypothesis import strategies as st
from hypothesis.stateful import RuleBasedStateMachine, initialize, invariant, rule

from tests.unitary.bounded_value.helpers import reference_read
from tests.utils.deployers import BOUNDED_VALUE_DEPLOYER

MAX_VALUE = 2**128
MAX_TIME = 7 * 24 * 60 * 60
MAX_DEVIATION = 5 * 10**18
TEST_VALUE_ID = "fz00"


class BoundedValueStateMachine(RuleBasedStateMachine):
    """Stateful fuzz test for the bounded value contract."""

    @initialize(
        initial_value=st.integers(min_value=0, max_value=MAX_VALUE),
        max_deviation=st.integers(min_value=0, max_value=MAX_DEVIATION),
    )
    def setup(self, initial_value, max_deviation):
        self.bounded_value = BOUNDED_VALUE_DEPLOYER.deploy([(TEST_VALUE_ID, initial_value, max_deviation)])
        self.max_deviation = max_deviation
        self.persisted_prev = initial_value
        self.persisted_target = initial_value
        self.elapsed_time = 0
        self.last_update_time = 0

    @rule(new_value=st.integers(min_value=0, max_value=MAX_VALUE))
    def update(self, new_value):
        """Update should match the Python reference implementation."""
        dt = self.elapsed_time - self.last_update_time
        expected = reference_read(
            self.persisted_prev,
            self.persisted_target,
            self.max_deviation,
            dt,
        )
        returned = self.bounded_value.internal.update(TEST_VALUE_ID, new_value)
        assert returned == expected
        self.persisted_prev = returned
        self.persisted_target = new_value
        self.last_update_time = self.elapsed_time

    @rule(dt=st.integers(min_value=1, max_value=MAX_TIME))
    def time_travel(self, dt):
        """Advance time."""
        boa.env.time_travel(dt)
        self.elapsed_time += dt

    @rule(new_max_deviation=st.integers(min_value=0, max_value=MAX_DEVIATION))
    def set_max_deviation(self, new_max_deviation):
        """Changing smoothing parameters should preserve continuity."""
        dt = self.elapsed_time - self.last_update_time
        current = reference_read(
            self.persisted_prev,
            self.persisted_target,
            self.max_deviation,
            dt,
        )
        self.bounded_value.internal.set_max_deviation(TEST_VALUE_ID, new_max_deviation)
        self.persisted_prev = current
        self.max_deviation = new_max_deviation
        self.last_update_time = self.elapsed_time

    @invariant()
    def read_matches_model(self):
        """Read should always match the latest model value."""
        dt = self.elapsed_time - self.last_update_time
        expected = reference_read(
            self.persisted_prev,
            self.persisted_target,
            self.max_deviation,
            dt,
        )
        assert self.bounded_value.internal.read(TEST_VALUE_ID) == expected

    @invariant()
    def no_overshoot(self):
        """Current value should always remain between persisted prev and target."""
        current = self.bounded_value.internal.read(TEST_VALUE_ID)
        lower = min(self.persisted_prev, self.persisted_target)
        upper = max(self.persisted_prev, self.persisted_target)
        assert lower <= current <= upper

    @invariant()
    def monotonic_convergence(self):
        """Between updates, value should move monotonically towards target."""
        current = self.bounded_value.internal.read(TEST_VALUE_ID)
        with boa.env.anchor():
            boa.env.time_travel(100)
            mid = self.bounded_value.internal.read(TEST_VALUE_ID)
            boa.env.time_travel(100)
            later = self.bounded_value.internal.read(TEST_VALUE_ID)

        if self.persisted_target >= current:
            assert current <= mid <= later
        else:
            assert current >= mid >= later


TestBoundedValue = BoundedValueStateMachine.TestCase
TestBoundedValue.settings = settings(
    deadline=None, phases=[Phase.explicit, Phase.reuse, Phase.generate, Phase.target]
)
