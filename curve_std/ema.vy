"""
@notice Exponential Moving Average helper module.
@author Curve Finance
@dev This module provides functionality to compute and persist
     multiple EMAs identified by a string ID.
     The module intentionally allows EMAs to be created at 
     construction time only.
"""

from curve_std import constants as c
from snekmate.utils import math

# @notice Exponential Moving Average instance
struct EMA:
    ema_time: uint256
    prev_value: uint256
    prev_timestamp: uint256


# @notice Initial configuration for an EMA instance
struct EMAConfig:
    ema_id: String[4]
    initial_value: uint256 
    ema_time: uint256


# @notice Wei Adjusted Decimal, represents 1.0 in 18 decimals fixed point.
WAD: constant(uint256) = c.WAD
# @notice Maximum number of different EMAs supported.
# @dev Since Vyper doesn't support dynamic memory allocation
# we keep this constant relatively small.
MAX_EMAS: constant(uint256) = 10


# @notice List of allowed EMAs ids.
# @dev useful to expose in the contract importing
# this module if it allows to pass arbitrary ids.
ALLOWED_EMAS: public(immutable(DynArray[String[4], MAX_EMAS]))

# @dev Vyper doesn't support passing value by reference yet, so we use
# a mapping and a 4 character string as a pointer to the corresponding
# storage slot.
# @dev This is not part of the public API and modifying it directly
# may lead to unexpected behavior. 
_emas: public(HashMap[String[4], EMA])


@deploy
def __init__(_ema_config: DynArray[EMAConfig, MAX_EMAS]):
    allow_list: DynArray[String[4], MAX_EMAS] = []
    for config: EMAConfig in _ema_config:
        # Setting an ema_time of 0 is not allowed, as it would break the math
        assert config.ema_time > 0  # dev: invalid ema_time

        id: String[4] = config.ema_id
        for existing_id: String[4] in allow_list:
            assert existing_id != id  # dev: duplicate ema id
        self._emas[id] = EMA(
            ema_time=config.ema_time,
            prev_value=config.initial_value,
            prev_timestamp=block.timestamp
        )
        allow_list.append(id)

    ALLOWED_EMAS = allow_list

@internal
@view
def _is_allowed(_ema_id: String[4]) -> bool:
    for ema_id: String[4] in ALLOWED_EMAS:
        if ema_id == _ema_id:
            return True
    return False


@internal
def set_ema_time(_ema_id: String[4], _ema_time: uint256):
    """
    @notice Update the ema_time for a given EMA id.
    @dev Setting an ema_time of 0 is not allowed, as it would break the math.
    @dev We first compute and save the current EMA value to avoid discontinuities
         in the smoothed value. For this reason exposing this function in a 
         permissionless way should be done with caution.
    @param _ema_id The identifier for the EMA
    @param _ema_time The new ema_time to set
    """
    assert self._is_allowed(_ema_id)  # dev: id not allowed
    self.compute_and_save(_ema_id, self._emas[_ema_id].prev_value)
    assert _ema_time > 0  # dev: invalid ema_time
    ema: EMA = self._emas[_ema_id]
    ema.ema_time = _ema_time
    self._emas[_ema_id] = ema


@internal
@view
def compute(_ema_id: String[4], _new_value: uint256) -> uint256:
    """
    @notice Compute the EMA value for a given EMA id and new value.
    @dev block.timestamp is chain dependent and can be manipulated within
            relatively small bounds. This can affect the EMA computation.
    @param _ema_id The identifier for the EMA
    @param _new_value The new value to compute the EMA for
    @return The computed EMA value
    """
    assert self._is_allowed(_ema_id)  # dev: id not allowed
    ema: EMA = self._emas[_ema_id]
    dt: uint256 = block.timestamp - ema.prev_timestamp

    if dt == 0:
        # The math below would return prev_value in this case anyway,
        # but let's save some gas by skipping it
        return ema.prev_value

    mul: uint256 = convert(math._wad_exp(-convert(dt * WAD // ema.ema_time, int256)), uint256)
    return (_new_value * mul + ema.prev_value * (WAD - mul)) // WAD


@internal
def _save(_ema_id: String[4], _value: uint256):
    """
    @notice Persist a pre-computed EMA value without recalculating
    @dev This function is not part of the public API and should be
         used with caution from other contracts: it can lead to
         inconsistent EMA values if the provided value does not match
         the expected EMA computation. It can be useful in scenarios 
         where the computation happens in a view function and the
         the result can only be saved later.
    @param _ema_id The identifier for the EMA
    @param _value The smoothed value to persist
    """
    assert self._is_allowed(_ema_id)  # dev: id not allowed
    ema: EMA = self._emas[_ema_id]
    ema.prev_value = _value
    ema.prev_timestamp = block.timestamp
    self._emas[_ema_id] = ema


@internal
def compute_and_save(_ema_id: String[4], _new_value: uint256) -> uint256:
    """
    @notice Compute and persist the EMA value for a given EMA id and new value.
    @param _ema_id The identifier for the EMA
    @param _new_value The new value to compute the EMA for
    @return The computed EMA value
    """
    smoothed: uint256 = self.compute(_ema_id, _new_value)
    self._save(_ema_id, smoothed)
    return smoothed