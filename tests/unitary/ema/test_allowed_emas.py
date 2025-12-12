from tests.unitary.ema.conftest import DUMMY_ALLOWED_EMAS


def test_default_behavior(ema):
    """Fixture-provided EMA exposes the configured id list."""
    observed = [ema.ALLOWED_EMAS(i) for i in range(len(DUMMY_ALLOWED_EMAS))]
    assert observed == DUMMY_ALLOWED_EMAS
