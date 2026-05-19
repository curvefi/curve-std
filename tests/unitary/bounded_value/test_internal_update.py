import boa

from tests.unitary.bounded_value.conftest import DUMMY_BOUNDED_VALUE_CONFIGS
from tests.unitary.bounded_value.helpers import reference_read


def test_default_behavior(bounded_value):
    """Update should persist the current smoothed value and queue a new target."""
    value_id, initial_value, max_deviation = DUMMY_BOUNDED_VALUE_CONFIGS[1]
    first_target = 3 * initial_value
    second_target = 4 * initial_value
    elapsed = 7

    bounded_value.internal.update(value_id, first_target)
    boa.env.time_travel(elapsed)

    result = bounded_value.internal.update(value_id, second_target)
    expected = reference_read(
        initial_value,
        first_target,
        max_deviation,
        elapsed,
    )

    slot = bounded_value.eval(f"self._values['{value_id}']")
    assert result == expected
    assert slot.prev_value == expected
    assert slot.prev_timestamp == boa.env.timestamp
    assert slot.target_value == second_target


def test_id_not_allowed(bounded_value):
    """Updating a non-whitelisted id should revert."""
    with boa.reverts(dev="id not allowed"):
        bounded_value.internal.update("nope", 1)
