# pragma version 0.4.3

@internal
def require(condition: bool, error: Bytes[4]):
    # TODO add multi argument error support
    if not condition:
        raw_revert(error)