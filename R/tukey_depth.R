#' Tukey (Halfspace) Depth
#'
#' Computes the Tukey halfspace depth of one or more query points with respect
#' to a reference distribution estimated from \code{data}.
#'
#' @details
#' Tukey depth is the canonical multivariate depth function. The deepest point
#' — the Tukey median — is a genuine robust generalization of the univariate
#' median, with breakdown point up to 1/(d+1). Depth is defined purely
#' geometrically via halfspaces with no distributional assumptions.
#'
#' Exact computation is O(n^(d-1)) and infeasible for d > 3. This
#' implementation uses an adaptive random projection approximation: depth is
#' estimated as the minimum over random unit vector projections of the fraction
#' of data points on either side of the query point's projection. The stopping
#' rule automatically determines when the estimate has stabilised.
#'
#' @param x Numeric matrix of query points (m x d), or a numeric vector of
#'   length d for a single point.
#' @param data Numeric matrix of reference data (n x d).
#' @param tol Convergence tolerance for the adaptive stopping rule. Default
#'   0.01 (1\% relative change).
#' @param batch_size Number of random projections per batch. Default 100.
#' @param min_batches Minimum number of batches before checking convergence.
#'   Default 5.
#' @param patience Number of consecutive stable batches to declare convergence.
#'   Default 3.
#' @param seed Integer random seed for reproducibility. Default 42.
#'
#' @return Numeric vector of depth values in [0, 0.5], one per query point.
#'
#' @references
#' Tukey, J. W. (1975). Mathematics and the picturing of data.
#' \emph{Proceedings of the International Congress of Mathematicians}, 2,
#' 523--531.
#'
#' Zuo, Y. & Serfling, R. (2000). General notions of statistical depth
#' function. \emph{Annals of Statistics}, 28(2), 461--482.
#'
#' @examples
#' \dontrun{
#' set.seed(42)
#' data <- matrix(rnorm(500), nrow = 100, ncol = 5)
#' x    <- matrix(rnorm(25),  nrow = 5,   ncol = 5)
#'
#' # Basic usage
#' tukey_depth(x, data)
#'
#' # Via compute_depth for full depth object
#' dd <- compute_depth(data, depth_fn = tukey_depth)
#' median(dd)
#' outliers(dd)
#' }
#'
#' @export
tukey_depth <- function(x, data,
                        tol         = 0.01,
                        batch_size  = 100L,
                        min_batches = 5L,
                        patience    = 3L,
                        seed        = 42L) {
  # Coerce inputs
  if (is.vector(x) && !is.list(x)) {
    x <- matrix(x, nrow = 1L)
  }
  if (!is.matrix(x))    x    <- as.matrix(x)
  if (!is.matrix(data)) data <- as.matrix(data)

  storage.mode(x)    <- "double"
  storage.mode(data) <- "double"

  .tukey_depth_cpp(
    x           = x,
    data        = data,
    tol         = tol,
    batch_size  = as.integer(batch_size),
    min_batches = as.integer(min_batches),
    patience    = as.integer(patience),
    seed        = as.integer(seed)
  )
}
