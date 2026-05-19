# pragma version 0.4.3
"""
@notice Linearly smoothed value helper module.
@author Curve Finance
"""

from curve_std import constants as c


event ValueSetMaxDeviation:
    value_id: String[4]
    max_deviation: uint256


event ValueUpdate:
    prev_value: uint256
    target_value: uint256


struct BoundedValue:
    max_deviation: uint256
    prev_value: uint256
    prev_timestamp: uint256
    target_value: uint256


struct BoundedValueConfig:
    value_id: String[4]
    initial_value: uint256
    max_deviation: uint256


MAX_VALUES: constant(uint256) = 10
WAD: constant(uint256) = c.WAD

ALLOWED_VALUES: public(immutable(DynArray[String[4], MAX_VALUES]))

_values: HashMap[String[4], BoundedValue]


@deploy
def __init__(_configs: DynArray[BoundedValueConfig, MAX_VALUES]):
    allow_list: DynArray[String[4], MAX_VALUES] = []
    for config: BoundedValueConfig in _configs:
        id: String[4] = config.value_id
        for existing_id: String[4] in allow_list:
            assert existing_id != id  # dev: duplicate value id

        self._values[id] = BoundedValue(
            max_deviation=config.max_deviation,
            prev_value=config.initial_value,
            prev_timestamp=block.timestamp,
            target_value=config.initial_value,
        )
        allow_list.append(id)
        log ValueSetMaxDeviation(value_id=id, max_deviation=config.max_deviation)
        log ValueUpdate(prev_value=config.initial_value, target_value=config.initial_value)

    ALLOWED_VALUES = allow_list


@internal
@view
def _is_allowed(_value_id: String[4]) -> bool:
    return self._values[_value_id].prev_timestamp > 0


@internal
def set_max_deviation(_value_id: String[4], _max_deviation: uint256):
    assert self._is_allowed(_value_id)  # dev: id not allowed

    value: BoundedValue = self._values[_value_id]
    value.prev_value = self.read(_value_id)
    value.prev_timestamp = block.timestamp
    value.max_deviation = _max_deviation
    self._values[_value_id] = value
    log ValueSetMaxDeviation(value_id=_value_id, max_deviation=_max_deviation)


@internal
@view
def read(_value_id: String[4]) -> uint256:
    assert self._is_allowed(_value_id)  # dev: id not allowed
    value: BoundedValue = self._values[_value_id]
    if value.prev_value == value.target_value:
        return value.prev_value

    dt: uint256 = block.timestamp - value.prev_timestamp
    if dt == 0:  # skipping value.max_deviation == 0 as a rare case
        return value.prev_value

    max_change: uint256 = value.max_deviation * dt * value.prev_value // WAD
    if unsafe_sub(value.target_value + max_change, value.prev_value) > 2 * max_change:
        return (
            value.prev_value + max_change
            if value.target_value > value.prev_value
            else value.prev_value - max_change
        )
    return value.target_value


@internal
def update(_value_id: String[4], _new_value: uint256) -> uint256:
    smoothed: uint256 = self.read(_value_id)
    value: BoundedValue = self._values[_value_id]
    value.prev_value=smoothed
    value.prev_timestamp=block.timestamp
    value.target_value=_new_value
    self._values[_value_id] = value
    log ValueUpdate(prev_value=smoothed, target_value=_new_value)
    return smoothed
