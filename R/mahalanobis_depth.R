#' Mahalanobis Depth
#'
#' Computes the Mahalanobis depth of one or more query points with respect
#' to a reference distribution estimated from \code{data}.
#'
#' @param x Numeric matrix of query points (m x d), or a numeric vector
#'   of length d for a single query point.
#' @param data Numeric matrix of reference data (n x d). Used to estimate
#'   the mean and covariance.
#' @param mu Optional numeric vector of length d. If supplied, overrides the
#'   mean estimated from \code{data}.
#' @param sigma Optional numeric matrix (d x d). If supplied, overrides the
#'   covariance estimated from \code{data}. Must be positive definite.
#'
#' @return Numeric vector of depth values in (0, 1], one per query point.
#'
#' @export
mahalanobis_depth <- function(x, data, mu = NULL, sigma = NULL) {
  # Coerce inputs to matrices
  if (is.vector(x) && !is.list(x)) {
    x <- matrix(x, nrow = 1)
  }
  if (!is.matrix(x)) {
    x <- as.matrix(x)
  }
  if (!is.matrix(data)) {
    data <- as.matrix(data)
  }

  # Storage mode must be double for Eigen
  storage.mode(x)    <- "double"
  storage.mode(data) <- "double"

  if (!is.null(mu))    mu    <- as.double(mu)
  if (!is.null(sigma)) sigma <- matrix(as.double(sigma), nrow = ncol(x))

  .mahalanobis_depth_cpp(x = x, data = data, mu = mu, sigma = sigma)
}
