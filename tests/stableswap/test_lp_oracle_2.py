import boa
import pytest
from hypothesis import given, settings
from hypothesis import strategies as st


WAD = 10**18
A_PRECISION = 10**4
MAX_A_RAW = 100_000 * A_PRECISION
UINT256_MAX = 2**256 - 1

SAFE_P_MAX = 500 * WAD


@pytest.fixture(scope="module")
def oracle():
    return boa.load("curve_std/stableswap/lp_oracle_2.vy")


@settings(
    max_examples=1000,
)
@given(
    a_eff=st.integers(min_value=1, max_value=100_000 * A_PRECISION),
    p_int=st.integers(min_value=10**16, max_value=10**20),  # [0.01, 100.0] * WAD
)
def test_oracle_against_invariant(oracle, a_eff, p_int):
    x, y = oracle.internal._get_x_y(a_eff, p_int)

    # Invariant at D=1:
    # ((4A(x+y-WAD) + WAD) * 4xy) ?= WAD^3
    assert (
        4 * a_eff * (x + y - WAD) // A_PRECISION + WAD
    ) * 4 * x * y == pytest.approx(WAD**3, rel=2e-6)

    # Marginal price from (x, y):
    # p_hat = (4A + 1/(4xy^2)) / (4A + 1/(4x^2y))
    term4a_wad = 4 * a_eff * WAD
    inv1 = A_PRECISION * (WAD**4) // (4 * x * y * y)
    inv2 = A_PRECISION * (WAD**4) // (4 * x * x * y)
    p_hat = ((term4a_wad + inv1) * WAD) // (term4a_wad + inv2)
    assert p_hat == pytest.approx(p_int, rel=2e-6)


@pytest.mark.parametrize(
    ("a_raw", "p"),
    [
        (1, 10**16),
        (1, WAD),
        (1, 10**20),
        (MAX_A_RAW, 10**16),
        (MAX_A_RAW, WAD),
        (MAX_A_RAW, 10**20),
    ],
)
def test_convergence_at_input_boundaries(oracle, a_raw, p):
    x, y = oracle.internal._get_x_y(a_raw, p)

    term4a_wad = 4 * a_raw * WAD
    inv1 = A_PRECISION * WAD**4 // (4 * x * y * y)
    inv2 = A_PRECISION * WAD**4 // (4 * x * x * y)
    p_hat = (term4a_wad + inv1) * WAD // (term4a_wad + inv2)

    assert p_hat == pytest.approx(p, rel=2e-6)


def test_p_prime_bracket_precision(oracle):
    # This point has 16*A_eff*x^2*y ~= 0.99. Integer-scale truncation would
    # replace the derivative's bracket ~= 1.99 with 1.
    a_raw = 2_530
    y = 41_516_227_294_767_401
    x = oracle.internal._x_from_y(a_raw, y)
    p = oracle.internal._p_from_y(a_raw, y)

    xx = x * x
    pxy = p * x * y // WAD
    p2y2 = p * p * y * y // WAD**2
    n_w2 = xx + p2y2 - pxy
    xy2_w2 = x * y * y // WAD

    bracket = WAD + 16 * a_raw * x * x * y // (A_PRECISION * WAD**2)
    d_w2 = xy2_w2 * bracket // WAD
    expected = 2 * n_w2 * WAD // d_w2

    coarse_bracket = 1 + 16 * a_raw * x * x * y // (A_PRECISION * WAD**3)
    coarse = 2 * n_w2 * WAD // (xy2_w2 * coarse_bracket)

    assert oracle.internal._p_prime_abs(a_raw, x, y, p) == expected
    assert expected != coarse


def test_newton_safe_p_bound_fits_uint256():
    # On this branch p >= x, so the strict-safe p boundary also conservatively
    # bounds x. Verify every raw multiplication in _p_prime_abs at y = WAD/2.
    y = WAD // 2
    p = SAFE_P_MAX - 1
    x = SAFE_P_MAX - 1

    assert p * p * y * y <= UINT256_MAX
    assert p * x * y <= UINT256_MAX

    bracket_numerator = 16 * MAX_A_RAW * x * x * y
    assert bracket_numerator <= UINT256_MAX

    bracket = WAD + bracket_numerator // (A_PRECISION * WAD**2)
    xy2_w2 = x * y * y // WAD
    assert xy2_w2 * bracket <= UINT256_MAX

    n_w2_upper_bound = x * x + p * p * y * y // WAD**2
    assert 2 * n_w2_upper_bound * WAD <= UINT256_MAX

    # This nearby round limit demonstrates which product determines the cap.
    assert (681 * WAD) ** 2 * y**2 > UINT256_MAX
