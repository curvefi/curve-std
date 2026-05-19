import boa

from tests.unitary.bounded_value.conftest import DUMMY_ALLOWED_VALUES


def test_default_behavior(bounded_value):
    """Internal setter updates the stored smoothing rate."""
    value_id = DUMMY_ALLOWED_VALUES[0]
    bounded_value.internal.set_max_deviation(value_id, 42)

    slot = bounded_value.eval(f"self._values['{value_id}']")
    assert slot.max_deviation == 42


def test_allowed_value(bounded_value):
    """Setting a non-whitelisted id should revert."""
    with boa.reverts(dev="id not allowed"):
        bounded_value.internal.set_max_deviation("nope", 1)
