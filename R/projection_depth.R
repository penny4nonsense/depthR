#' Projection Depth
#'
#' Computes the projection depth of one or more query points with respect
#' to a reference distribution estimated from \code{data}, using an adaptive
#' random projection approximation with parallel computation.
#'
#' @details
#' Projection depth is defined via the Stahel-Donoho outlyingness — the
#' supremum over all directions of the robust univariate Z-score of the
#' projected point, using median and MAD as location and scale. This makes
#' it fully robust with a high breakdown point, and affine invariant.
#'
#' The deepest point under projection depth is a genuine robust estimator
#' of multivariate location.
#'
#' @param x Numeric matrix of query points (m x d), or a numeric vector of
#'   length d for a single point.
#' @param data Numeric matrix of reference data (n x d).
#' @param tol Convergence tolerance for the adaptive stopping rule. Default
#'   0.01.
#' @param batch_size Number of random projections per batch. Default 100.
#' @param min_batches Minimum batches before checking convergence. Default 5.
#' @param patience Consecutive stable batches to declare convergence.
#'   Default 3.
#' @param seed Integer random seed for reproducibility. Default 42.
#'
#' @return Numeric vector of depth values in (0, 1], one per query point.
#'
#' @references
#' Zuo, Y. & Serfling, R. (2000). General notions of statistical depth
#' function. \emph{Annals of Statistics}, 28(2), 461--482.
#'
#' @examples
#' \dontrun{
#' set.seed(42)
#' data <- matrix(rnorm(500), nrow = 100, ncol = 5)
#' x    <- matrix(rnorm(25),  nrow = 5,   ncol = 5)
#'
#' projection_depth(x, data)
#'
#' dd <- compute_depth(data, depth_fn = projection_depth)
#' median(dd)
#' outliers(dd)
#' }
#'
#' @export
projection_depth <- function(x, data,
                              tol         = 0.01,
                              batch_size  = 100L,
                              min_batches = 5L,
                              patience    = 3L,
                              seed        = 42L) {
  if (is.vector(x) && !is.list(x)) {
    x <- matrix(x, nrow = 1L)
  }
  if (!is.matrix(x))    x    <- as.matrix(x)
  if (!is.matrix(data)) data <- as.matrix(data)

  storage.mode(x)    <- "double"
  storage.mode(data) <- "double"

  .projection_depth_cpp(
    x           = x,
    data        = data,
    tol         = tol,
    batch_size  = as.integer(batch_size),
    min_batches = as.integer(min_batches),
    patience    = as.integer(patience),
    seed        = as.integer(seed)
  )
}
