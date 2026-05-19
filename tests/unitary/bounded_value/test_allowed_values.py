from tests.unitary.bounded_value.conftest import DUMMY_ALLOWED_VALUES


def test_default_behavior(bounded_value):
    """Fixture-provided contract exposes the configured id list."""
    observed = [
        bounded_value.ALLOWED_VALUES(i) for i in range(len(DUMMY_ALLOWED_VALUES))
    ]
    assert observed == DUMMY_ALLOWED_VALUES
