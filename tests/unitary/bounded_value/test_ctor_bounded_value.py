import boa

from tests.utils.constants import MAX_EMAS
from tests.utils.deployers import BOUNDED_VALUE_DEPLOYER


def test_default_behavior():
    """Constructor should persist the allowed ids as provided."""
    for size in range(MAX_EMAS + 1):
        allowed_ids = [f"v{index:03d}" for index in range(size)]
        configs = [
            (value_id, (i + 1) * 10**18, (i + 1) * 10**16)
            for i, value_id in enumerate(allowed_ids)
        ]
        bounded_value = BOUNDED_VALUE_DEPLOYER.deploy(configs)

        observed = [bounded_value.ALLOWED_VALUES(i) for i in range(size)]
        assert observed == allowed_ids


def test_duplicate_id_reverts():
    """Constructor should reject duplicate ids."""
    with boa.reverts(dev="duplicate value id"):
        BOUNDED_VALUE_DEPLOYER.deploy([("dup0", 1, 1), ("dup0", 2, 2)])
