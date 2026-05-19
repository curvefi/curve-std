from tests.unitary.bounded_value.conftest import DUMMY_ALLOWED_VALUES


def test_default_behavior_known_id(bounded_value):
    """Internal check should return True for whitelisted ids."""
    assert bounded_value.internal._is_allowed(DUMMY_ALLOWED_VALUES[0]) is True


def test_default_behavior_unknown_id(bounded_value):
    """Unknown ids should be rejected."""
    assert bounded_value.internal._is_allowed("nope") is False
