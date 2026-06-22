# =============================================================================
# depth object — core infrastructure
#
# All depth functions in depthR return a 'depth' S3 object via compute_depth().
# Derived quantities (median, outliers, ranks, etc.) are cheap S3 methods
# that operate on the stored depth values without recomputing anything.
# =============================================================================

#' @importFrom Rcpp evalCpp
#' @importFrom stats median quantile
#' @importFrom graphics abline legend points
#' @importFrom RcppParallel RcppParallelLibs
#' @useDynLib depthR, .registration = TRUE
NULL

# -----------------------------------------------------------------------------
# Constructor
# -----------------------------------------------------------------------------

#' Compute Depth
#'
#' Computes the statistical depth of every row of \code{data} with respect to
#' the empirical distribution of \code{data}, returning a \code{depth} object
#' from which medians, outliers, ranks, and other derived quantities can be
#' extracted cheaply without recomputing depth.
#'
#' @param data Numeric matrix (n x d) or data frame. Rows are observations,
#'   columns are variables.
#' @param depth_fn Depth function to use. Must have signature
#'   \code{f(x, data, ...)} and return a numeric vector of length
#'   \code{nrow(x)}. Defaults to \code{mahalanobis_depth}.
#' @param ... Additional arguments forwarded to \code{depth_fn}.
#'
#' @return An object of class \code{"depth"} with components:
#'   \describe{
#'     \item{depths}{Numeric vector of length n — depth of each observation.}
#'     \item{data}{The original data matrix.}
#'     \item{depth_fn}{The depth function used.}
#'     \item{n}{Number of observations.}
#'     \item{d}{Dimension.}
#'     \item{call}{The matched call.}
#'   }
#'
#' @examples
#' \donttest{
#' set.seed(42)
#' data <- matrix(rnorm(500), nrow = 100, ncol = 5)
#' dd   <- compute_depth(data, depth_fn = mahalanobis_depth)
#'
#' median(dd)
#' rank(dd)
#' outliers(dd)
#' summary(dd)
#' plot(dd)
#' }
#'
#' @export
compute_depth <- function(data, depth_fn = mahalanobis_depth, ...) {
  cl <- match.call()

  if (is.data.frame(data)) data <- as.matrix(data)
  if (!is.matrix(data))    data <- as.matrix(data)
  storage.mode(data) <- "double"

  if (nrow(data) < 2L) {
    stop("data must have at least 2 rows.")
  }

  # Single expensive call — every derived method uses these stored values
  depths <- depth_fn(x = data, data = data, ...)

  structure(
    list(
      depths   = depths,
      data     = data,
      depth_fn = depth_fn,
      n        = nrow(data),
      d        = ncol(data),
      call     = cl
    ),
    class = "depth"
  )
}


# -----------------------------------------------------------------------------
# print / summary
# -----------------------------------------------------------------------------

#' @export
print.depth <- function(x, ...) {
  cat("Depth object\n")
  cat("  Call      :", deparse(x$call), "\n")
  cat("  n         :", x$n, "observations\n")
  cat("  d         :", x$d, "dimensions\n")
  cat("  Depth fn  :", deparse(substitute(x$depth_fn)), "\n")
  cat("  Depth range: [",
      round(min(x$depths), 4), ", ",
      round(max(x$depths), 4), "]\n", sep = "")
  invisible(x)
}

#' @export
summary.depth <- function(object, outlier_threshold = 0.05, ...) {
  d      <- object$depths
  thresh <- quantile(d, outlier_threshold)
  n_out  <- sum(d <= thresh)

  cat("Depth summary\n")
  cat("  n observations  :", object$n, "\n")
  cat("  d dimensions    :", object$d, "\n")
  cat("\n  Depth distribution:\n")
  print(round(quantile(d, c(0, 0.1, 0.25, 0.5, 0.75, 0.9, 1)), 4))
  cat("\n  Deepest point   : row", which.max(d),
      "(depth =", round(max(d), 4), ")\n")
  cat("  Shallowest point: row", which.min(d),
      "(depth =", round(min(d), 4), ")\n")
  cat("  Outliers (depth <=", round(thresh, 4), "):",
      n_out, "observations\n")
  invisible(object)
}


# -----------------------------------------------------------------------------
# median
# -----------------------------------------------------------------------------

#' Median
#'
#' Generic function for computing the median. For \code{depth} objects,
#' returns the deepest observation. For all other objects, delegates to
#' \code{stats::median}.
#'
#' @param x An object. For \code{depth} objects, see \code{\link{median.depth}}.
#' @param ... Additional arguments passed to methods.
#' @return For \code{depth} objects, a named list with elements \code{point},
#'   \code{depth}, and \code{index}. For other objects, see
#'   \code{\link[stats]{median}}.
#' @export
median <- function(x, ...) UseMethod("median")

#' @export
median.default <- function(x, na.rm = FALSE, ...) {
  stats::median(x, na.rm = na.rm)
}

#' Depth-Based Median
#'
#' Returns the observation with the highest depth — the multivariate analog
#' of the median.
#'
#' @param x A \code{depth} object from \code{compute_depth()}.
#' @param ... Ignored.
#'
#' @return A named list:
#'   \describe{
#'     \item{point}{Numeric vector of length d — the deepest observation.}
#'     \item{depth}{Depth value at the median.}
#'     \item{index}{Row index of the deepest observation in the data.}
#'   }
#'
#' @export
median.depth <- function(x, ...) {
  idx <- which.max(x$depths)
  list(
    point = x$data[idx, ],
    depth = x$depths[idx],
    index = idx
  )
}


# -----------------------------------------------------------------------------
# rank
# -----------------------------------------------------------------------------

#' Rank
#'
#' Generic function for ranking. For \code{depth} objects, returns
#' depth-based ranks with rank 1 assigned to the deepest observation.
#' For all other objects, delegates to \code{base::rank}.
#'
#' @param x An object. For \code{depth} objects, see \code{\link{rank.depth}}.
#' @param ... Additional arguments passed to methods.
#' @return For \code{depth} objects, an integer vector of length n where
#'   rank 1 is the deepest observation. For other objects, see
#'   \code{\link[base]{rank}}.
#' @export
rank <- function(x, ...) UseMethod("rank")

#' @export
rank.default <- function(x, na.last = TRUE, ties.method = "average", ...) {
  base::rank(x, na.last = na.last, ties.method = ties.method)
}

#' Depth-Based Ranks
#'
#' Ranks observations by depth. Rank 1 is assigned to the deepest (most
#' central) observation; rank n to the shallowest (most outlying).
#'
#' @param x A \code{depth} object from \code{compute_depth()}.
#' @param ... Ignored.
#'
#' @return Integer vector of length n. Rank 1 = deepest.
#'
#' @export
rank.depth <- function(x, ...) {
  # Negate so that the highest depth gets rank 1
  as.integer(base::rank(-x$depths, ties.method = "average"))
}


# -----------------------------------------------------------------------------
# outliers
# -----------------------------------------------------------------------------

#' Depth-Based Outlier Detection
#'
#' Flags observations whose depth falls below a threshold as outliers.
#' The threshold can be specified as a quantile of the depth distribution
#' (default) or as an absolute depth cutoff.
#'
#' @param x A \code{depth} object from \code{compute_depth()}.
#' @param threshold Numeric scalar in (0, 1). Interpreted as a quantile of
#'   the depth distribution when \code{absolute = FALSE} (default): the
#'   bottom \code{threshold} fraction of observations are flagged as outliers.
#'   When \code{absolute = TRUE}, any observation with depth below
#'   \code{threshold} is flagged.
#' @param absolute Logical. If \code{TRUE}, \code{threshold} is an absolute
#'   depth cutoff rather than a quantile. Default \code{FALSE}.
#' @param ... Ignored.
#'
#' @return A named list:
#'   \describe{
#'     \item{outlier}{Logical vector of length n — \code{TRUE} for outliers.}
#'     \item{indices}{Integer vector of row indices of outlying observations.}
#'     \item{points}{Matrix of outlying observations.}
#'     \item{depths}{Depth values of outlying observations.}
#'     \item{threshold}{The actual depth cutoff used.}
#'   }
#'
#' @examples
#' \donttest{
#' set.seed(42)
#' data <- matrix(rnorm(500), nrow = 100, ncol = 5)
#' dd   <- compute_depth(data)
#'
#' # Flag bottom 5% by depth (default)
#' outliers(dd)
#'
#' # Flag bottom 10%
#' outliers(dd, threshold = 0.10)
#'
#' # Absolute depth cutoff
#' outliers(dd, threshold = 0.05, absolute = TRUE)
#' }
#'
#' @export
outliers <- function(x, threshold = 0.05, absolute = FALSE, ...) {
  UseMethod("outliers")
}

#' @export
outliers.depth <- function(x, threshold = 0.05, absolute = FALSE, ...) {
  if (threshold <= 0 || threshold >= 1) {
    stop("threshold must be in (0, 1).")
  }

  cutoff <- if (absolute) {
    threshold
  } else {
    quantile(x$depths, threshold)
  }

  is_outlier <- x$depths <= cutoff
  idx        <- which(is_outlier)

  list(
    outlier   = is_outlier,
    indices   = idx,
    points    = x$data[idx, , drop = FALSE],
    depths    = x$depths[idx],
    threshold = cutoff
  )
}


# -----------------------------------------------------------------------------
# central_region
# -----------------------------------------------------------------------------

#' Depth-Based Central Region
#'
#' Returns the set of observations whose depth is at or above the
#' \code{alpha}-th quantile of the depth distribution — the multivariate
#' analog of a quantile interval.
#'
#' @param x A \code{depth} object from \code{compute_depth()}.
#' @param alpha Numeric scalar in (0, 1). The central region contains the
#'   deepest \code{1 - alpha} fraction of observations. Default 0.50
#'   (the inner half).
#' @param ... Ignored.
#'
#' @return A named list:
#'   \describe{
#'     \item{indices}{Row indices of observations in the central region.}
#'     \item{points}{Matrix of observations in the central region.}
#'     \item{depths}{Depth values of those observations.}
#'     \item{threshold}{The depth cutoff used.}
#'     \item{alpha}{The alpha level used.}
#'   }
#'
#' @export
central_region <- function(x, alpha = 0.50, ...) {
  UseMethod("central_region")
}

#' @export
central_region.depth <- function(x, alpha = 0.50, ...) {
  if (alpha <= 0 || alpha >= 1) {
    stop("alpha must be in (0, 1).")
  }

  cutoff <- quantile(x$depths, alpha)
  inside <- x$depths >= cutoff
  idx    <- which(inside)

  list(
    indices   = idx,
    points    = x$data[idx, , drop = FALSE],
    depths    = x$depths[idx],
    threshold = cutoff,
    alpha     = alpha
  )
}


# -----------------------------------------------------------------------------
# plot
# -----------------------------------------------------------------------------

#' Plot a Depth Object
#'
#' For d = 2, plots the data with point size proportional to depth and
#' outliers flagged in red. For d > 2, plots a depth profile
#' (observation index vs depth value).
#'
#' @param x A \code{depth} object from \code{compute_depth()}.
#' @param outlier_threshold Quantile threshold for flagging outliers.
#'   Default 0.05.
#' @param main Plot title. If \code{NULL} (default), a sensible title is
#'   generated automatically.
#' @param ... Additional arguments passed to \code{plot()}.
#'
#' @return Invisibly returns \code{x}, the original \code{depth} object.
#'   Called primarily for its side effect of producing a plot.
#'
#' @export
plot.depth <- function(x, outlier_threshold = 0.05, main = NULL, ...) {
  d      <- x$depths
  is_out <- d <= quantile(d, outlier_threshold)
  cols   <- ifelse(is_out, "firebrick", "steelblue")

  if (x$d == 2L) {
    main <- if (is.null(main)) "Depth plot" else main
    plot(x$data,
         col  = cols,
         pch  = ifelse(is_out, 4L, 19L),
         cex  = 0.4 + 1.2 * (d - min(d)) / (max(d) - min(d) + 1e-10),
         xlab = "x1", ylab = "x2",
         main = main, ...)
    legend("topright",
           legend = c("Outlier", "Regular"),
           col    = c("firebrick", "steelblue"),
           pch    = c(4L, 19L),
           bty    = "n")
  } else {
    main <- if (is.null(main)) paste0("Depth profile (d = ", x$d, ")") else main
    plot(seq_along(d), d,
         col  = cols,
         pch  = ifelse(is_out, 4L, 19L),
         xlab = "Observation index",
         ylab = "Depth",
         main = main, ...)
    abline(h = quantile(d, outlier_threshold), lty = 2L, col = "firebrick")
    legend("topright",
           legend = c("Outlier", "Regular"),
           col    = c("firebrick", "steelblue"),
           pch    = c(4L, 19L),
           bty    = "n")
  }
  invisible(x)
}
