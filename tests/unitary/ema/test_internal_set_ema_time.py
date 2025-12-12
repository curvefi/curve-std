import boa

from tests.unitary.ema.conftest import DUMMY_ALLOWED_EMAS


def test_default_behavior(ema):
    """Internal setter updates the stored ema_time value."""
    ema_id = DUMMY_ALLOWED_EMAS[0]
    ema.internal.set_ema_time(ema_id, 42)

    slot = ema.emas(ema_id)
    assert slot.ema_time == 42


def test_allowed_ema(ema):
    """Setting a non-whitelisted id should revert."""
    with boa.reverts(dev="id not allowed"):
        ema.internal.set_ema_time("nope", 1)


def test_non_zero_ema_time(ema):
    """ema_time must be strictly positive."""
    with boa.reverts(dev="invalid ema_time"):
        ema.internal.set_ema_time(DUMMY_ALLOWED_EMAS[0], 0)
