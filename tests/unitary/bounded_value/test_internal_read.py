import boa

from tests.unitary.bounded_value.conftest import DUMMY_BOUNDED_VALUE_CONFIGS
from tests.unitary.bounded_value.helpers import reference_read


def test_default_behavior_no_time_elapsed(bounded_value):
    """When no time has passed the previous value is returned."""
    value_id, initial_value, _ = DUMMY_BOUNDED_VALUE_CONFIGS[0]
    assert bounded_value.internal.read(value_id) == initial_value


def test_default_behavior_time_elapsed(bounded_value):
    """Read should linearly move from prev_value to target_value."""
    value_id, initial_value, max_deviation = DUMMY_BOUNDED_VALUE_CONFIGS[0]
    target_value = 2 * initial_value
    elapsed = 30

    bounded_value.internal.update(value_id, target_value)
    boa.env.time_travel(elapsed)

    observed = bounded_value.internal.read(value_id)
    expected = reference_read(
        initial_value,
        target_value,
        max_deviation,
        elapsed,
    )
    assert observed == expected


def test_default_behavior_downward_target(bounded_value):
    """Read should linearly move down to a lower target."""
    value_id, initial_value, max_deviation = DUMMY_BOUNDED_VALUE_CONFIGS[0]
    target_value = initial_value // 2
    elapsed = 30

    bounded_value.internal.update(value_id, target_value)
    boa.env.time_travel(elapsed)

    observed = bounded_value.internal.read(value_id)
    expected = reference_read(initial_value, target_value, max_deviation, elapsed)
    assert observed == expected


def test_id_not_allowed(bounded_value):
    """Reading a non-whitelisted id should revert."""
    with boa.reverts(dev="id not allowed"):
        bounded_value.internal.read("nope")
