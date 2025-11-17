# pragma version 0.4.3

@pure
@internal
def sub_or_zero(a: uint256, b: uint256) -> uint256:
    return unsafe_sub(max(a, b), b)


@pure
@internal
def div_up(numerator: uint256, denominator: uint256) -> uint256:
    # TODO figure out if we can use unsafes here
    return (numerator + denominator - 1) // denominator
