import boa

from tests.unitary.bounded_value.helpers import reference_read
from tests.utils.deployers import BOUNDED_VALUE_DEPLOYER

VALUE_ID = "e2e0"
INITIAL_VALUE = 10**18
MAX_DEVIATION = 10**16


def test_only_last_update_matters():
    """Multiple updates in same block should only consider the last target value."""
    bounded_value = BOUNDED_VALUE_DEPLOYER.deploy([(VALUE_ID, INITIAL_VALUE, MAX_DEVIATION)])
    last_value = 5 * 10**18
    elapsed = 300

    for i in range(10):
        bounded_value.internal.update(VALUE_ID, i * 10**18)

    bounded_value.internal.update(VALUE_ID, last_value)

    boa.env.time_travel(elapsed)
    result = bounded_value.internal.read(VALUE_ID)

    expected = reference_read(INITIAL_VALUE, last_value, MAX_DEVIATION, elapsed)
    assert result == expected
