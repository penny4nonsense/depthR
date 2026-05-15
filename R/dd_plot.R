# =============================================================================
# DD-plot (Depth-Depth Plot)
#
# A classical tool for nonparametric two-sample comparison via depth functions.
# Each observation from both samples is plotted at coordinates
# (depth wrt X, depth wrt Y). Points from the same distribution cluster
# near the main diagonal; distributional differences produce separation.
# =============================================================================

#' Depth-Depth Plot
#'
#' Computes and plots the depth-depth (DD) plot for two samples. Each
#' observation from both samples is assigned two depth values — its depth
#' with respect to the empirical distribution of \code{x} and its depth
#' with respect to the empirical distribution of \code{y}. Points from the
#' same distribution cluster near the main diagonal.
#'
#' @details
#' The DD-plot was introduced by Liu, Parelius & Singh (1999) as a
#' nonparametric graphical tool for two-sample comparison. It is the
#' multivariate analog of the QQ-plot, using depth in place of quantiles.
#'
#' If the two distributions are identical, all points should fall near the
#' diagonal. Systematic deviations indicate location shifts (points above
#' or below the diagonal) or scale/shape differences (spread of points
#' away from the diagonal).
#'
#' @param x Numeric matrix (n1 x d) — first sample.
#' @param y Numeric matrix (n2 x d) — second sample. Must have the same
#'   number of columns as \code{x}.
#' @param depth_fn Depth function to use. Must have signature
#'   \code{f(x, data, ...)}. Defaults to \code{simplicial_depth}.
#' @param plot Logical. If \code{TRUE} (default), produce the plot.
#' @param xlab Label for the x-axis. Defaults to "Depth wrt X".
#' @param ylab Label for the y-axis. Defaults to "Depth wrt Y".
#' @param main Plot title. Defaults to "DD-Plot".
#' @param col_x Color for points from \code{x}. Default \code{"steelblue"}.
#' @param col_y Color for points from \code{y}. Default \code{"firebrick"}.
#' @param pch_x Plot character for points from \code{x}. Default 19.
#' @param pch_y Plot character for points from \code{y}. Default 17.
#' @param legend Logical. If \code{TRUE} (default), add a legend.
#' @param ... Additional arguments passed to \code{depth_fn}.
#'
#' @return Invisibly returns a data frame with columns:
#'   \describe{
#'     \item{depth_x}{Depth of each observation with respect to \code{x}.}
#'     \item{depth_y}{Depth of each observation with respect to \code{y}.}
#'     \item{sample}{Factor indicating which sample the observation came from.}
#'   }
#'
#' @references
#' Liu, R. Y., Parelius, J. M. & Singh, K. (1999). Multivariate analysis
#' by data depth: descriptive statistics, graphics and inference.
#' \emph{Annals of Statistics}, 27(3), 783--858.
#'
#' @examples
#' \dontrun{
#' set.seed(42)
#' # Same distribution — points near diagonal
#' x <- matrix(rnorm(200), nrow = 100, ncol = 2)
#' y <- matrix(rnorm(200), nrow = 100, ncol = 2)
#' dd_plot(x, y, depth_fn = simplicial_depth)
#'
#' # Location shift — points systematically off diagonal
#' y_shift <- matrix(rnorm(200, mean = 1), nrow = 100, ncol = 2)
#' dd_plot(x, y_shift, depth_fn = tukey_depth)
#'
#' # Store results without plotting
#' result <- dd_plot(x, y, plot = FALSE)
#' head(result)
#' }
#'
#' @export
dd_plot <- function(x, y,
                    depth_fn = simplicial_depth,
                    plot     = TRUE,
                    xlab     = "Depth wrt X",
                    ylab     = "Depth wrt Y",
                    main     = "DD-Plot",
                    col_x    = "steelblue",
                    col_y    = "firebrick",
                    pch_x    = 19L,
                    pch_y    = 17L,
                    legend   = TRUE,
                    ...) {

  # Input validation
  if (!is.matrix(x)) x <- as.matrix(x)
  if (!is.matrix(y)) y <- as.matrix(y)

  if (ncol(x) != ncol(y)) {
    stop("x and y must have the same number of columns (dimension d).")
  }

  storage.mode(x) <- "double"
  storage.mode(y) <- "double"

  n1 <- nrow(x)
  n2 <- nrow(y)

  # Combine both samples for depth computation
  both <- rbind(x, y)

  # Compute depth of all points wrt X distribution
  depth_wrt_x <- depth_fn(x = both, data = x, ...)

  # Compute depth of all points wrt Y distribution
  depth_wrt_y <- depth_fn(x = both, data = y, ...)

  # Build result data frame
  result <- data.frame(
    depth_x = depth_wrt_x,
    depth_y = depth_wrt_y,
    sample  = factor(c(rep("X", n1), rep("Y", n2)), levels = c("X", "Y"))
  )

  if (plot) {
    # Determine axis limits — same scale on both axes
    all_depths <- c(depth_wrt_x, depth_wrt_y)
    lim <- c(0, max(all_depths) * 1.05)

    # Base plot
    plot(
      result$depth_x[result$sample == "X"],
      result$depth_y[result$sample == "X"],
      col  = col_x,
      pch  = pch_x,
      xlim = lim,
      ylim = lim,
      xlab = xlab,
      ylab = ylab,
      main = main
    )

    # Add Y sample points
    points(
      result$depth_x[result$sample == "Y"],
      result$depth_y[result$sample == "Y"],
      col = col_y,
      pch = pch_y
    )

    # Diagonal reference line
    abline(0, 1, lty = 2L, col = "grey40")

    if (legend) {
      legend(
        "topleft",
        legend = c("Sample X", "Sample Y"),
        col    = c(col_x, col_y),
        pch    = c(pch_x, pch_y),
        bty    = "n"
      )
    }
  }

  invisible(result)
}
