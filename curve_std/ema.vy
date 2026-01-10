from curve_std import constants as c
from snekmate.utils import math

WAD: constant(uint256) = c.WAD
MAX_EMAS: constant(uint256) = 10


struct EMA:
    ema_time: uint256
    prev_value: uint256
    prev_timestamp: uint256


# List of allowed EMAs ids, useful to expose in the contract importing
# this module if it allows to pass arbitrary ids.
ALLOWED_EMAS: public(immutable(DynArray[String[4], MAX_EMAS]))

# Vyper doesn't support passing value by reference yet, so we use
# a mapping and a 4 character string as a pointer to the corresponding
# storage slot.
emas: public(HashMap[String[4], EMA])


@deploy
def __init__(_allowed_emas: DynArray[String[4], MAX_EMAS]):
    ALLOWED_EMAS = _allowed_emas


@internal
@view
def _is_allowed(_ema_id: String[4]) -> bool:
    for ema_id: String[4] in ALLOWED_EMAS:
        if ema_id == _ema_id:
            return True
    return False


@internal
def setup(_ema_id: String[4], _initial_value: uint256, _ema_time: uint256):
    # Setting an ema_time of 0 is not allowed, as it would break the math
    # Setting an ema_time of 1 is equivalent to no smoothing at all
    assert self._is_allowed(_ema_id)  # dev: id not allowed
    assert _ema_time > 0  # dev: invalid ema_time
    ema: EMA = self.emas[_ema_id]
    ema.ema_time = _ema_time
    ema.prev_value = _initial_value
    ema.prev_timestamp = block.timestamp
    self.emas[_ema_id] = ema


@internal
def set_ema_time(_ema_id: String[4], _ema_time: uint256):
    # Setting an ema_time of 0 is not allowed, as it would break the math
    # Setting an ema_time of 1 is equivalent to no smoothing at all
    assert self._is_allowed(_ema_id)  # dev: id not allowed
    assert _ema_time > 0  # dev: invalid ema_time
    ema: EMA = self.emas[_ema_id]
    ema.ema_time = _ema_time
    self.emas[_ema_id] = ema


@internal
@view
def compute(_ema_id: String[4], _new_value: uint256) -> uint256:
    assert self._is_allowed(_ema_id)  # dev: id not allowed
    ema: EMA = self.emas[_ema_id]
    assert ema.ema_time > 0  # dev: ema not initialized
    dt: uint256 = block.timestamp - ema.prev_timestamp

    if dt == 0:
        # The math below would return prev_value in this case anyway,
        # but let's save some gas by skipping it
        return ema.prev_value

    mul: uint256 = convert(math._wad_exp(-convert(dt * WAD // ema.ema_time, int256)), uint256)
    return (ema.prev_value * mul + _new_value * (WAD - mul)) // WAD


@internal
def update(_ema_id: String[4], _new_value: uint256) -> uint256:
    smoothed: uint256 = self.compute(_ema_id, _new_value)
    self.save(_ema_id, smoothed)
    return smoothed


@internal
def save(_ema_id: String[4], _value: uint256):
    """
    @notice Persist a pre-computed EMA value without recalculating
    @param _ema_id The identifier for the EMA
    @param _value The smoothed value to persist
    """
    assert self._is_allowed(_ema_id)  # dev: id not allowed
    ema: EMA = self.emas[_ema_id]
    # redundant when called via update, but needed when save is called directly
    assert ema.ema_time > 0  # dev: ema not initialized
    ema.prev_value = _value
    ema.prev_timestamp = block.timestamp
    self.emas[_ema_id] = ema
