library(testthat)
library(depthR)

# Shared test data
set.seed(99)
data2d <- matrix(rnorm(200), nrow = 100, ncol = 2)
data5d <- matrix(rnorm(500), nrow = 100, ncol = 5)
dd2    <- compute_depth(data2d, depth_fn = mahalanobis_depth)
dd5    <- compute_depth(data5d, depth_fn = mahalanobis_depth)

# -----------------------------------------------------------------------------
# compute_depth
# -----------------------------------------------------------------------------

test_that("compute_depth returns a depth object", {
  expect_s3_class(dd2, "depth")
})

test_that("compute_depth object has correct structure", {
  expect_named(dd2, c("depths", "data", "depth_fn", "n", "d", "call"))
  expect_equal(dd2$n, 100L)
  expect_equal(dd2$d, 2L)
  expect_length(dd2$depths, 100L)
})

test_that("compute_depth accepts a data frame", {
  df <- as.data.frame(data2d)
  dd <- compute_depth(df, depth_fn = mahalanobis_depth)
  expect_s3_class(dd, "depth")
  expect_equal(dd$n, 100L)
})

test_that("compute_depth rejects fewer than 2 rows", {
  expect_error(compute_depth(matrix(1, nrow = 1, ncol = 2)))
})

# -----------------------------------------------------------------------------
# median
# -----------------------------------------------------------------------------

test_that("median.depth returns correct structure", {
  m <- median(dd2)
  expect_named(m, c("point", "depth", "index"))
  expect_length(m$point, 2L)
  expect_true(m$depth > 0 && m$depth <= 1)
  expect_true(m$index >= 1L && m$index <= 100L)
})

test_that("median.depth returns the deepest point", {
  m <- median(dd5)
  expect_equal(m$depth, max(dd5$depths))
})

# -----------------------------------------------------------------------------
# rank
# -----------------------------------------------------------------------------

test_that("rank.depth returns integer vector of length n", {
  r <- rank(dd2)
  expect_length(r, 100L)
  expect_type(r, "integer")
})

test_that("rank.depth assigns rank 1 to the deepest point", {
  r   <- rank(dd2)
  idx <- which.max(dd2$depths)
  expect_equal(r[idx], 1L)
})

test_that("rank.depth assigns rank n to the shallowest point", {
  r   <- rank(dd2)
  idx <- which.min(dd2$depths)
  expect_equal(r[idx], 100L)
})

test_that("rank.depth produces all ranks 1..n with no gaps", {
  r <- rank(dd2)
  expect_equal(sort(r), 1:100)
})

# -----------------------------------------------------------------------------
# outliers
# -----------------------------------------------------------------------------

test_that("outliers.depth returns correct structure", {
  out <- outliers(dd2)
  expect_named(out, c("outlier", "indices", "points", "depths", "threshold"))
})

test_that("outliers.depth flags approximately the right fraction", {
  out <- outliers(dd2, threshold = 0.10)
  expect_true(length(out$indices) >= 5L && length(out$indices) <= 15L)
})

test_that("outliers.depth absolute mode uses cutoff directly", {
  out <- outliers(dd2, threshold = 0.80, absolute = TRUE)
  expect_true(all(out$depths <= 0.80))
})

test_that("outliers.depth rejects threshold outside (0,1)", {
  expect_error(outliers(dd2, threshold = 0))
  expect_error(outliers(dd2, threshold = 1))
})

test_that("outlier logical vector length matches n", {
  out <- outliers(dd5)
  expect_length(out$outlier, 100L)
})

# -----------------------------------------------------------------------------
# central_region
# -----------------------------------------------------------------------------

test_that("central_region returns correct structure", {
  cr <- central_region(dd2)
  expect_named(cr, c("indices", "points", "depths", "threshold", "alpha"))
})

test_that("central_region alpha=0.5 returns roughly the inner half", {
  cr <- central_region(dd2, alpha = 0.50)
  expect_true(length(cr$indices) >= 45L && length(cr$indices) <= 55L)
})

test_that("all points in central region have depth >= threshold", {
  cr <- central_region(dd5, alpha = 0.25)
  expect_true(all(cr$depths >= cr$threshold))
})

test_that("central_region rejects alpha outside (0,1)", {
  expect_error(central_region(dd2, alpha = 0))
  expect_error(central_region(dd2, alpha = 1))
})

# -----------------------------------------------------------------------------
# print / summary — just check they run without error
# -----------------------------------------------------------------------------

test_that("print.depth runs without error", {
  expect_output(print(dd2))
})

test_that("summary.depth runs without error", {
  expect_output(summary(dd2))
})

# -----------------------------------------------------------------------------
# plot — just check it runs without error
# -----------------------------------------------------------------------------

test_that("plot.depth runs for d=2 without error", {
  expect_silent(plot(dd2))
})

test_that("plot.depth runs for d>2 without error", {
  expect_silent(plot(dd5))
})
