from __future__ import annotations

from decimal import ROUND_FLOOR, Decimal, localcontext

WAD = 10**18


def reference_compute(prev_value: int, new_value: int, ema_time: int, dt: int) -> int:
    """Pure Python replica of the EMA compute logic."""
    if dt == 0:
        return prev_value

    exponent_wad = -((dt * WAD) // ema_time)
    with localcontext() as ctx:
        ctx.prec = 80
        exponent = Decimal(exponent_wad) / Decimal(WAD)
        scaled = exponent.exp() * Decimal(WAD)
        mul = int(scaled.to_integral_value(rounding=ROUND_FLOOR))
    return (prev_value * mul + new_value * (WAD - mul)) // WAD
