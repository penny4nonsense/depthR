library(testthat)
library(depthR)

# -----------------------------------------------------------------------------
# Basic correctness
# -----------------------------------------------------------------------------

test_that("tukey_depth returns values in [0, 0.5]", {
  set.seed(1)
  data <- matrix(rnorm(500), nrow = 100, ncol = 5)
  x    <- matrix(rnorm(25),  nrow = 5,   ncol = 5)
  d    <- tukey_depth(x, data)
  expect_true(all(d >= 0))
  expect_true(all(d <= 0.5))
})

test_that("central point has higher depth than outlying point", {
  set.seed(2)
  data   <- matrix(rnorm(500), nrow = 100, ncol = 5)
  center <- matrix(colMeans(data), nrow = 1)
  far    <- matrix(colMeans(data) + 10, nrow = 1)
  d_center <- tukey_depth(center, data)
  d_far    <- tukey_depth(far,    data)
  expect_true(d_center > d_far)
})

test_that("point far outside data cloud has depth near 0", {
  set.seed(3)
  data <- matrix(rnorm(500), nrow = 100, ncol = 5)
  far  <- matrix(rep(100, 5), nrow = 1)
  d    <- tukey_depth(far, data)
  expect_true(d < 0.05)
})

test_that("depth is symmetric around center for symmetric data", {
  set.seed(4)
  data <- matrix(rnorm(400), nrow = 200, ncol = 2)
  x1   <- matrix(c( 0.5,  0.5), nrow = 1)
  x2   <- matrix(c(-0.5, -0.5), nrow = 1)
  d1   <- tukey_depth(x1, data)
  d2   <- tukey_depth(x2, data)
  expect_true(abs(d1 - d2) < 0.15)
})

# -----------------------------------------------------------------------------
# Input handling
# -----------------------------------------------------------------------------

test_that("single vector input is handled correctly", {
  set.seed(5)
  data <- matrix(rnorm(200), nrow = 100, ncol = 2)
  x    <- c(0.0, 0.0)
  d    <- tukey_depth(x, data)
  expect_length(d, 1)
  expect_true(d >= 0 && d <= 0.5)
})

test_that("dimension mismatch raises an error", {
  data <- matrix(rnorm(200), nrow = 100, ncol = 2)
  x    <- matrix(rnorm(15),  nrow = 5,   ncol = 3)
  expect_error(tukey_depth(x, data))
})

test_that("multiple query points return correct length", {
  set.seed(6)
  data <- matrix(rnorm(500), nrow = 100, ncol = 5)
  x    <- matrix(rnorm(50),  nrow = 10,  ncol = 5)
  d    <- tukey_depth(x, data)
  expect_length(d, 10)
})

# -----------------------------------------------------------------------------
# Reproducibility
# -----------------------------------------------------------------------------

test_that("same seed produces identical results", {
  set.seed(7)
  data <- matrix(rnorm(500), nrow = 100, ncol = 5)
  x    <- matrix(rnorm(25),  nrow = 5,   ncol = 5)
  d1   <- tukey_depth(x, data, seed = 123L)
  d2   <- tukey_depth(x, data, seed = 123L)
  expect_equal(d1, d2)
})

test_that("different seeds produce slightly different results", {
  set.seed(8)
  data <- matrix(rnorm(500), nrow = 100, ncol = 5)
  x    <- matrix(colMeans(data), nrow = 1)
  d1   <- tukey_depth(x, data, seed = 1L)
  d2   <- tukey_depth(x, data, seed = 99L)
  # Not identical but should be close
  expect_true(abs(d1 - d2) < 0.05)
})

# -----------------------------------------------------------------------------
# Integration with depth object
# -----------------------------------------------------------------------------

test_that("tukey_depth works with compute_depth", {
  set.seed(9)
  data <- matrix(rnorm(500), nrow = 100, ncol = 5)
  dd   <- compute_depth(data, depth_fn = tukey_depth)
  expect_s3_class(dd, "depth")
  expect_length(dd$depths, 100)
  expect_true(all(dd$depths >= 0 & dd$depths <= 0.5))
})

test_that("median from tukey depth is near data center", {
  set.seed(10)
  data <- matrix(rnorm(600), nrow = 200, ncol = 3)
  dd   <- compute_depth(data, depth_fn = tukey_depth)
  m    <- median(dd)
  # Tukey median should be close to origin for standard normal data
  expect_true(sqrt(sum(m$point^2)) < 1.0)
})

test_that("outliers from tukey depth are in the tails", {
  set.seed(11)
  data <- matrix(rnorm(300), nrow = 100, ncol = 3)
  dd   <- compute_depth(data, depth_fn = tukey_depth)
  out  <- outliers(dd, threshold = 0.10)
  # Outliers should have lower depth than non-outliers
  non_out_depths <- dd$depths[!out$outlier]
  expect_true(mean(out$depths) < mean(non_out_depths))
})
