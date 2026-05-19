import boa

CONTRACTS_PATH = "curve_std/"

EMA_DEPLOYER = boa.load_partial(CONTRACTS_PATH + "ema.vy")
BOUNDED_VALUE_DEPLOYER = boa.load_partial(CONTRACTS_PATH + "bounded_value.vy")
