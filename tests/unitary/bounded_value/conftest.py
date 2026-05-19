import pytest

from tests.utils.deployers import BOUNDED_VALUE_DEPLOYER

DUMMY_ALLOWED_VALUES = ["sym0", "sym1", "sym2", "sym3", "sym4"]
# BoundedValueConfig struct: (value_id, initial_value, max_deviation)
DUMMY_BOUNDED_VALUE_CONFIGS = [
    (value_id, (i + 1) * 10**18, (i + 1) * 10**16)
    for i, value_id in enumerate(DUMMY_ALLOWED_VALUES)
]


@pytest.fixture
def bounded_value():
    """Deploy a bounded value contract seeded with predictable ids."""
    return BOUNDED_VALUE_DEPLOYER.deploy(DUMMY_BOUNDED_VALUE_CONFIGS)
