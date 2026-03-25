# pragma version 0.4.3
"""
@notice Exponential Moving Average helper module.
@author Curve Finance
@dev - This module provides functionality to compute and persist
     multiple EMAs identified by a string ID.
     - The EMA is computed from the queued value from the
     previous update, then queues the newly supplied value
     for the next update to reduce manipulation risk.
     - The module intentionally allows EMAs to be created at
     construction time only.
"""

from curve_std import constants as c
from snekmate.utils import math


event EmaSetTime:
    ema_id: String[4]
    ema_time: uint256


event EmaUpdate:
    prev_value: uint256
    queued_value: uint256


# @notice Exponential Moving Average instance
struct EMA:
    ema_time: uint256
    prev_value: uint256
    prev_timestamp: uint256
    queued_value: uint256


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
_emas: HashMap[String[4], EMA]


@deploy
def __init__(_ema_config: DynArray[EMAConfig, MAX_EMAS]):
    """
    @notice Initialize the EMA instances based on the provided configuration.
    @param _ema_config List of EMA configurations
    """
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
            prev_timestamp=block.timestamp,
            queued_value=config.initial_value,
        )
        allow_list.append(id)
        log EmaSetTime(ema_id=id, ema_time=config.ema_time)
        log EmaUpdate(prev_value=config.initial_value, queued_value=config.initial_value)

    ALLOWED_EMAS = allow_list


@internal
@view
def _is_allowed(_ema_id: String[4]) -> bool:
    """
    @dev We use ema_time > 0 as a sentinel for initialized EMAs.
    @param _ema_id The identifier for the EMA
    """
    return self._emas[_ema_id].ema_time > 0


@internal
def set_ema_time(_ema_id: String[4], _ema_time: uint256):
    """
    @notice Update the ema_time for a given EMA id.
    @dev Setting an ema_time of 0 is not allowed, as it would break the math.
    @dev We first update the current EMA value to avoid discontinuities
         in the smoothed value.
    @param _ema_id The identifier for the EMA
    @param _ema_time The new ema_time to set
    """
    assert self._is_allowed(_ema_id)  # dev: id not allowed
    self.update(_ema_id, self._emas[_ema_id].queued_value)
    assert _ema_time > 0  # dev: invalid ema_time
    self._emas[_ema_id].ema_time = _ema_time
    log EmaSetTime(ema_id=_ema_id, ema_time=_ema_time)


@internal
@view
def read(_ema_id: String[4]) -> uint256:
    """
    @notice Compute the EMA value for a given EMA id.
    @dev The queued value from the previous update is used as input.
    @dev block.timestamp is chain dependent and can be manipulated within
         relatively small bounds. This can affect the EMA computation.
    @param _ema_id The identifier for the EMA
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
    return (ema.prev_value * mul + ema.queued_value * (WAD - mul)) // WAD


@internal
def update(_ema_id: String[4], _new_value: uint256) -> uint256:
    """
    @notice Compute and persist the EMA value for a given EMA id.
    @dev The queued value from the previous update is used as input, and
         the new value is queued for the next update.
    @dev The queueing mechanism helps to reduce manipulation risk, in a real
         usage scenario a flash loan attacker would have to sustain their
         beyond a single transaction to impact on the EMA, as repaying the
         flash loan would queue a benign value for the next update.
    @param _ema_id The identifier for the EMA
    @param _new_value The new value to queue for the next update
    @return The computed EMA value
    """
    # (possibly) computing the smoothed value more than once
    # in the same transaction to prioritize correctness.
    # All other approaches considered so far would make the
    # API of this library more error prone (e.g. direct access
    # to storage variables can lead to inconsistent EMAs).
    smoothed: uint256 = self.read(_ema_id)

    self._emas[_ema_id] = EMA(
        ema_time=self._emas[_ema_id].ema_time,
        prev_value=smoothed,
        prev_timestamp=block.timestamp,
        queued_value=_new_value,
    )
    log EmaUpdate(prev_value=smoothed, queued_value=_new_value)
    return smoothed
