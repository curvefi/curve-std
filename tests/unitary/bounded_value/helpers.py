WAD = 10**18


def reference_read(
    prev_value: int,
    target_value: int,
    max_deviation: int,
    dt: int,
) -> int:
    """Pure Python replica of the smoothed read logic."""
    if dt == 0 or max_deviation == 0 or prev_value == target_value:
        return prev_value

    max_change = prev_value * dt * max_deviation // WAD
    if target_value > prev_value:
        return min(target_value, prev_value + max_change)
    return max(target_value, max(0, prev_value - max_change))
