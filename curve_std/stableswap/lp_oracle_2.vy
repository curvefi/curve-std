# pragma version 0.4.3

# =============================================================================
# StableSwap (n=2), D=1, fixed-point WAD=1e18
#
# Goal:
#   Given amplification A and target marginal price p_target = -dx/dy,
#   compute portfolio value in x-units:
#     V = x + p_target * y
#   where (x, y) lies on the StableSwap invariant.
#
# Notation:
#   A_eff := A_raw / A_PRECISION
#   y := y/D, with D=1 normalization
#   g(y) := p(y) - p_target
#
# 1) Invariant and x(y)
#   For n=2, D=1:
#     4*A_eff*(x + y) + 1 = 4*A_eff + 1/(4*x*y)
#   Rearranged:
#     4*A_eff*x^2 + (4*A_eff*(y-1) + 1)*x - 1/(4*y) = 0
#   With b1 = 4*A_eff*(y-1)+1:
#     x(y) = (-b1 + sqrt(b1^2 + 4*A_eff/y)) / (8*A_eff)
#
# 2) Marginal price p(y)
#   From implicit differentiation of F(x,y)=0:
#     p(y) = -dx/dy
#          = (4*A_eff + 1/(4*x*y^2)) / (4*A_eff + 1/(4*x^2*y))
#
# 3) Value at fixed y
#     V(y) = x(y) + p_target * y
#
# 4) Root equation solved by numeric method
#     g(y) = p(y) - p_target = 0
#   On the relevant branch p(y) is monotone decreasing in y, so bracketing works.
#
# 5) Mapping used by this implementation
#   b1   = WAD + (4*A_raw*(y - WAD))/A_PRECISION
#   rad2 = b1^2 + (4*A_raw*WAD^3)/(A_PRECISION*y)
#   x    = ((-b1 + sqrt(rad2)) * A_PRECISION) / (8*A_raw)
#   p    = ((4*A_raw*x/A_PRECISION + WAD^3/(4*y^2)) * WAD) /
#          (4*A_raw*x/A_PRECISION + WAD^3/(4*x*y))
#
# 6) Symmetry for p_target < 1
#   Solve reciprocal branch at p_inv ~= WAD^2 / p_target, then map back:
#     V(p_target) = p_target * V(p_inv)
#     (x, y) at p_target is (y, x) at p_inv.
#
# 7) Method used here: bracketed Newton on g(y)
#   Newton steps use the closed-form derivative p'(y). The monotone-price
#   bracket [lo, hi] is updated on every iteration. After the Newton budget is
#   exhausted, as well as for an unsafe or out-of-bracket Newton step, the next
#   candidate falls through to the bisection midpoint.
# =============================================================================
WAD: constant(uint256) = 10**18
WAD2: constant(uint256) = WAD * WAD
WAD3: constant(uint256) = WAD2 * WAD

A_PRECISION: constant(uint256) = 10**4
MAX_A: constant(uint256) = 100_000
MAX_A_RAW: constant(uint256) = MAX_A * A_PRECISION

# Conservative limits, something's off if variables hit these boundaries
# Can be revised for specific use-cases
MIN_P: constant(uint256) = 10**16  # 0.01
MAX_P: constant(uint256) = 10**20  # 100

MAX_NEWTON_ITERS: constant(uint256) = 16
BISECTION_ITERS: constant(uint256) = 60
MAX_ITERS: constant(uint256) = MAX_NEWTON_ITERS + BISECTION_ITERS
PRICE_TOL_REL: constant(uint256) = 10**6  # 0.01 bps

# With y <= WAD/2, the raw product p^2*y^2 in Newton's derivative has the
# uint256 hard limit p < 680.56*WAD; this bound leaves 1.85x headroom.
# On the same branch the invariant gives p(y) >= x(y), so bounding p also
# keeps x around 500*WAD, far below its independent 833_456.55*WAD limit.
SAFE_P_MAX: constant(uint256) = 500 * WAD


@internal
@pure
def _x_from_y(A_raw: uint256, y: uint256) -> uint256:
    # Invariant quadratic in x:
    #   4A*x^2 + (4A*(y-1)+1)*x - 1/(4y) = 0
    # Positive root:
    #   x(y) = (-b1 + sqrt(b1^2 + 4A/y)) / (8A), b1 = 1 - 4A*(1-y)
    #
    # Error bound for fixed-point rounding (absolute, in output wei):
    #   x*     = ((sqrt(b^2 + t) - b) * A_PRECISION) / (8*A_raw)      (exact real)
    #   b      = WAD - (4*A_raw*(WAD-y))/A_PRECISION
    #   t      = (4*A_raw*WAD^3)/(A_PRECISION*y)
    #   b_hat  = WAD - floor(4*A_raw*(WAD-y)/A_PRECISION), |b_hat-b| < 1
    #   t_hat  = floor(t),                                    |t_hat-t| < 1
    #   r_hat  = floor(sqrt(b_hat^2 + t_hat))
    #   x_hat  = floor(((r_hat - b_hat) * A_PRECISION)/(8*A_raw))
    # Using |d sqrt(b^2+t)/db| <= 1 and |d sqrt(b^2+t)/dt| = 1/(2*sqrt(b^2+t)) << 1:
    #   |r_hat - sqrt(b^2+t)| < 2
    # Therefore:
    #   |x_hat - x*| < 1 + (3*A_PRECISION)/(8*A_raw)
    #   => for A_raw >= 1:            |x_hat - x*| < 3751 wei
    #   => for A_raw >= A_PRECISION:  |x_hat - x*| < 2 wei
    b1: int256 = convert(WAD, int256) - convert(
        4 * A_raw * (WAD - y) // A_PRECISION, int256
    )  # revert on y > WAD

    abs_b1: uint256 = convert(abs(b1), uint256)
    term: uint256 = (4 * A_raw * WAD3) // (A_PRECISION * y)  # revert on y == 0
    rad: int256 = convert(isqrt(abs_b1**2 + term), int256)
    return (convert(rad - b1, uint256) * A_PRECISION) // (8 * A_raw)  # revert on A_raw == 0


@internal
@pure
def _p_from_y(A_raw: uint256, y: uint256) -> uint256:
    # p(y) = -dx/dy:
    #   p(y) = (4A + 1/(4*x*y^2)) / (4A + 1/(4*x^2*y))
    # Multiply numerator and denominator by x to reduce one division by x:
    #   p(y) = (4A*x + 1/(4*y^2)) / (4A*x + 1/(4*x*y))
    #
    # Error propagation (absolute, in output wei):
    #   p*   = WAD * (N / D), with:
    #          N = a + u,  D = a + v
    #          a = (4*A_raw/A_PRECISION) * x*
    #          u = WAD^3/(4*y^2)
    #          v = WAD^3/(4*x* y)
    #   p_hat uses x_hat from _x_from_y and floor divisions.
    #
    # Let E_x = |x_hat - x*| from _x_from_y bound, alpha = 4*A_raw/A_PRECISION,
    # beta = WAD^3/(4*y). For x* > E_x:
    #   |delta_a| <= alpha * E_x + 1
    #   |delta_u| < 1
    #   |delta_v| <= beta * E_x / (x* * (x* - E_x)) + 1
    #
    # Define:
    #   deltaN = |delta_a| + |delta_u|
    #   deltaD = |delta_a| + |delta_v|
    # Then for deltaD < D:
    #   |p_hat - p*| <= 1 + WAD * (deltaN * D + N * deltaD) / (D * (D - deltaD))
    #
    # Equivalent relative form (first-order):
    #   |p_hat - p*| / p* ~= deltaN / N + deltaD / D + 1 / p*
    #
    # Empirical examples on sampled domain y in [WAD/10^5, WAD/2+1]
    # (dense y-sweep, high-precision reference; illustrative, not a proof):
    #   A_eff = 1      (A_raw = 1 * A_PRECISION):       |p_hat - p*| <= ~6.3e3 wei
    #   A_eff = 200    (A_raw = 200 * A_PRECISION):     |p_hat - p*| <= ~4.1e3 wei
    #   A_eff = 10_000 (A_raw = 10_000 * A_PRECISION):  |p_hat - p*| <= ~1.3e4 wei
    #   Relative error in all those sweeps is about 1e-18.
    x: uint256 = self._x_from_y(A_raw, y)  # reverts on y == 0; x == 0 is impossible

    term4A: uint256 = (4 * A_raw * x) // A_PRECISION
    return unsafe_div(
        (term4A + unsafe_div(WAD3, 4 * y * y)) * WAD,
        term4A + unsafe_div(WAD3, 4 * x * y),
    )


@internal
@pure
def _p_prime_abs(A_raw: uint256, x: uint256, y: uint256, p: uint256) -> uint256:
    # From implicit differentiation of the invariant:
    #   p'(y) = -2 * (x^2 - p*x*y + p^2*y^2)
    #            / (x*y^2 * (16*A_eff*x^2*y + 1)).
    xx: uint256 = x * x
    pxy: uint256 = unsafe_div(p * x * y, WAD)
    p2y2: uint256 = unsafe_div(p * p * y * y, WAD2)
    # For r = p*y/WAD, integer arithmetic gives pxy = floor(x*r) and
    # p2y2 = floor(r^2). If r < x, pxy < x^2; otherwise p2y2 >= pxy.
    # Thus xx + p2y2 > pxy in both cases, including floor rounding.
    n_w2: uint256 = xx + p2y2 - pxy

    bracket: uint256 = ((16 * A_raw * x * x * y) // (A_PRECISION * WAD2) + WAD)
    xy2_w2: uint256 = unsafe_div(x * y * y, WAD)
    d_w2: uint256 = unsafe_div(xy2_w2 * bracket, WAD)
    return unsafe_div(2 * n_w2 * WAD, d_w2)


@internal
@pure
def _y_initial_guess(A_raw: uint256, p: uint256) -> uint256:
    # High-A asymptotic on the p >= WAD branch:
    #   y_0 = 1 / (4 * sqrt(A_eff * (p - 1))).
    if p <= WAD:
        return WAD // 2

    return isqrt(
        unsafe_div(
            WAD3 * A_PRECISION,
            16 * A_raw * unsafe_sub(p, WAD),
        )
    )


@internal
@pure
def _y_newton(A_raw: uint256, p: uint256) -> uint256:
    # Solve g(y) = p(y) - p_target = 0 on monotone branch y in (0, 1/2].
    # The shared loop evaluates a candidate before proposing the next one, so
    # the 60-iteration bisection suffix evaluates 59 midpoints. This suffices
    # because the initial bracket width WAD/2 is strictly less than 2**59.
    assert p >= WAD
    lo: uint256 = 1
    hi: uint256 = WAD // 2 + 1  # y for p = 1
    y: uint256 = self._y_initial_guess(A_raw, p)
    if y <= lo:
        y = lo + 1
    if y >= hi:
        y = hi - 1

    tol_abs: uint256 = unsafe_div(p, PRICE_TOL_REL)
    for iteration: uint256 in range(MAX_ITERS):
        pm: uint256 = self._p_from_y(A_raw, y)

        if pm > p:
            if unsafe_sub(pm, p) <= tol_abs:
                return y
            lo = y
        else:
            if unsafe_sub(p, pm) <= tol_abs:
                return y
            hi = y

        if unsafe_sub(hi, lo) <= 1:
            return hi


        # Once the Newton budget is exhausted, zero reaches the common
        # bisection fallback below without evaluating the derivative.
        y_new: uint256 = 0
        if iteration < MAX_NEWTON_ITERS and pm < SAFE_P_MAX:
            x: uint256 = self._x_from_y(A_raw, y)
            # With g(y) = pm - p and ppy representing |g'(y)|*WAD:
            # y_new = y - g/g' = y + (pm*WAD/ppy - p*WAD/ppy).
            ppy: uint256 = self._p_prime_abs(A_raw, x, y, pm)
            delta: uint256 = unsafe_sub(
                unsafe_div(pm * WAD, ppy),
                unsafe_div(p * WAD, ppy),
            )
            # Each quotient is < 5e38, so a wrapped negative correction cannot
            # wrap back into the bracket after it is added to y.
            y_new = unsafe_add(y, delta)

        if y_new <= lo or y_new >= hi:  # bisection fallback
            y_new = unsafe_div(lo + hi, 2)
        y = y_new

    raise "Didn't converge"  # Unreachable


@internal
@pure
def _get_x_y(A_raw: uint256, p: uint256) -> (uint256, uint256):
    """
    @dev Computes the StableSwap point (x, y) corresponding to target marginal price p and D=1.
    @param A_raw Raw amplification coefficient scaled by A_PRECISION.
    @param p Target marginal price.
    @return (x, y) (x, y)-coordinates on the invariant.
    """
    assert A_raw > 0
    assert A_raw <= MAX_A_RAW
    assert MIN_P <= p and p <= MAX_P

    if p < WAD:
        p_inv: uint256 = unsafe_div(WAD2 + p // 2, p)
        y_inv: uint256 = self._y_newton(A_raw, p_inv)
        x_inv: uint256 = self._x_from_y(A_raw, y_inv)
        return y_inv, x_inv

    y: uint256 = self._y_newton(A_raw, p)
    x: uint256 = self._x_from_y(A_raw, y)
    return x, y


@internal
@pure
def _portfolio_value(A_raw: uint256, p: uint256) -> uint256:
    """
    @dev Computes portfolio value x + p*y at the StableSwap point matching target price p.
    @param A_raw Raw amplification coefficient scaled by A_PRECISION.
    @param p Target marginal price.
    @return Portfolio value denominated in x-units.
    """
    # Since p(y) = -dx/dy and portfolio_value(y) = x(y) + p(y) * y,
    # we get d(portfolio_value)/dp = y. On this branch y <= 1/2, so
    # portfolio_value as a function of price is 1/2-Lipschitz:
    # |portfolio_value(y1) - portfolio_value(y0)| <= 1/2 * |p(y1) - p(y0)|.
    # Therefore it is safe to search for y using an error tolerance in p:
    # the resulting error in portfolio_value is no larger than the price error
    # and is at most half of it on this branch.
    x: uint256 = 0
    y: uint256 = 0
    x, y = self._get_x_y(A_raw, p)
    # Let q be the actual price of the found point, with |q - p| < eps.
    # We want portfolio_value(p) = x(p) + p * y(p), but we have x(q), y(q).
    #
    # Use x + p * y, not x + q * y.
    # Indeed, portfolio_value'(p) = y(p), so x(q) + q * y(q) differs from
    # portfolio_value(p) by a first-order term ~ y(p) * (q - p).
    # In x(q) + p * y(q), this first-order term cancels because dx/dp = -p * dy/dp.
    # Hence its error is only second-order in |q - p|.
    return x + p * y // WAD


@external
@pure
def portfolio_value(_A_raw: uint256, _p: uint256) -> uint256:
    """
    @notice Returns StableSwap portfolio value x + p*y for the point with marginal price p.
    @param _A_raw Raw amplification coefficient scaled by A_PRECISION.
    @param _p Target marginal price.
    @return Portfolio value denominated in x-units.
    """
    return self._portfolio_value(_A_raw, _p)
