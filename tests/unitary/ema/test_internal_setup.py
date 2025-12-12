import boa

from tests.unitary.ema.conftest import DUMMY_ALLOWED_EMAS


def test_default_behavior(ema):
    """setup should populate storage with the provided values."""
    ema_id = DUMMY_ALLOWED_EMAS[0]
    initial_value = 123456789
    ema_time = 15

    ema.internal.setup(ema_id, initial_value, ema_time)

    slot = ema.emas(ema_id)
    assert slot.ema_time == ema_time
    assert slot.prev_value == initial_value
    assert slot.prev_timestamp > 0


def test_allowed_ema(ema):
    """setup rejects ids that are not whitelisted."""
    with boa.reverts(dev="id not allowed"):
        ema.internal.setup("nope", 1, 1)


def test_non_zero_ema_time(ema):
    """setup enforces ema_time > 0."""
    with boa.reverts(dev="invalid ema_time"):
        ema.internal.setup(DUMMY_ALLOWED_EMAS[0], 1, 0)
