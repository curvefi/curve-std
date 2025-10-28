@pure
@internal
def sub_or_zero(a: uint256, b: uint256) -> uint256:
    return unsafe_sub(max(a, b), b)
