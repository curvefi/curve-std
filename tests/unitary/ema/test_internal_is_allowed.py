from __future__ import annotations

from tests.unitary.ema.conftest import DUMMY_ALLOWED_EMAS


def test_default_behavior_known_id(ema):
    """Internal check should return True for whitelisted ids."""
    assert ema.internal._is_allowed(DUMMY_ALLOWED_EMAS[0]) is True


def test_default_behavior_unknown_id(ema):
    """Unknown ids should be rejected."""
    assert ema.internal._is_allowed("nope") is False
