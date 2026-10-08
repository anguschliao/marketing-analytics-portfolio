
import numpy as np


def geometric_adstock(spend, theta):
    """
    Apply geometric adstock to a weekly spend series.

    Parameters
    ----------
    spend : array-like
        Weekly advertising spend in chronological order.
    theta : float
        Weekly carryover rate between 0 and 1.

    Returns
    -------
    np.ndarray
        Adstock-adjusted advertising pressure.

    Notes
    -----
    A[t] = spend[t] + theta * A[t-1]

    This is unnormalized geometric adstock.
    """
    spend = np.asarray(spend, dtype=float)

    if spend.ndim != 1:
        raise ValueError("Spend must be a one-dimensional array.")

    if not np.all(np.isfinite(spend)):
        raise ValueError("Spend must contain only finite values.")

    if np.any(spend < 0):
        raise ValueError("Spend cannot be negative.")

    if not np.isfinite(theta) or not 0 <= theta < 1:
        raise ValueError("Theta must be between 0 and 1 (exclusive).")

    result = np.zeros_like(spend)

    previous = 0.0

    for i, value in enumerate(spend):
        previous = value + theta * previous
        result[i] = previous

    return result


def adstock_half_life(theta):
    """
    Return the advertising half-life in weeks.
    """
    if not np.isfinite(theta) or not 0 <= theta < 1:
        raise ValueError("Theta must be between 0 and 1 (exclusive).")

    if theta == 0:
        return 0.0

    return np.log(0.5) / np.log(theta)

def hill_saturation(x, alpha, half_saturation):
    """
    Apply Hill saturation to nonnegative advertising pressure.

    H(x) = x^alpha / (x^alpha + half_saturation^alpha)

    Parameters
    ----------
    x : array-like
        Nonnegative adstock-adjusted media pressure.
    alpha : float
        Positive curve shape parameter.
    half_saturation : float
        Positive pressure level producing a response of 0.5.

    Returns
    -------
    np.ndarray
        Normalized response between 0 and 1.
    """
    x = np.asarray(x, dtype=float)

    if x.ndim != 1:
        raise ValueError("Input must be one-dimensional.")

    if not np.all(np.isfinite(x)) or np.any(x < 0):
        raise ValueError("Input must be finite and nonnegative.")

    if not np.isfinite(alpha) or alpha <= 0:
        raise ValueError("Alpha must be positive and finite.")

    if not np.isfinite(half_saturation) or half_saturation <= 0:
        raise ValueError(
            "Half-saturation must be positive and finite."
        )

    # Numerically stable equivalent of the Hill equation.
    result = np.zeros_like(x)

    positive = x > 0

    log_ratio = alpha * (
        np.log(half_saturation) - np.log(x[positive])
    )

    result[positive] = np.exp(
        -np.logaddexp(0.0, log_ratio)
    )

    return result