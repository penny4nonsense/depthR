library(testthat)
library(depthR)

# -----------------------------------------------------------------------------
# Basic correctness
# -----------------------------------------------------------------------------

test_that("spatial_depth returns values in [0, 1]", {
  set.seed(1)
  data <- matrix(rnorm(500), nrow = 100, ncol = 5)
  x    <- matrix(rnorm(25),  nrow = 5,   ncol = 5)
  d    <- spatial_depth(x, data)
  expect_true(all(d >= 0))
  expect_true(all(d <= 1))
})

test_that("central point has higher depth than outlying point", {
  set.seed(2)
  data   <- matrix(rnorm(500), nrow = 100, ncol = 5)
  center <- matrix(colMeans(data), nrow = 1)
  far    <- matrix(colMeans(data) + 10, nrow = 1)
  d_center <- spatial_depth(center, data)
  d_far    <- spatial_depth(far,    data)
  expect_true(d_center > d_far)
})

test_that("point far outside data cloud has depth near 0", {
  set.seed(3)
  data <- matrix(rnorm(500), nrow = 100, ncol = 5)
  far  <- matrix(rep(100, 5), nrow = 1)
  d    <- spatial_depth(far, data)
  expect_true(d < 0.05)
})

test_that("depth decreases as point moves away from center", {
  set.seed(4)
  data <- matrix(rnorm(1000), nrow = 200, ncol = 5)
  mu   <- colMeans(data)
  offsets <- c(0, 1, 2, 4, 8)
  pts <- t(sapply(offsets, function(o) { v <- mu; v[1] <- v[1] + o; v }))
  depths <- spatial_depth(pts, data)
  expect_true(all(diff(depths) < 0))
})

test_that("depth is symmetric around center for symmetric data", {
  set.seed(5)
  data <- matrix(rnorm(400), nrow = 200, ncol = 2)
  x1   <- matrix(c( 0.5,  0.5), nrow = 1)
  x2   <- matrix(c(-0.5, -0.5), nrow = 1)
  d1   <- spatial_depth(x1, data)
  d2   <- spatial_depth(x2, data)
  expect_true(abs(d1 - d2) < 0.10)
})

# -----------------------------------------------------------------------------
# Input handling
# -----------------------------------------------------------------------------

test_that("single vector input is handled correctly", {
  set.seed(6)
  data <- matrix(rnorm(200), nrow = 100, ncol = 2)
  x    <- c(0.0, 0.0)
  d    <- spatial_depth(x, data)
  expect_length(d, 1)
  expect_true(d >= 0 && d <= 1)
})

test_that("dimension mismatch raises an error", {
  data <- matrix(rnorm(200), nrow = 100, ncol = 2)
  x    <- matrix(rnorm(15),  nrow = 5,   ncol = 3)
  expect_error(spatial_depth(x, data))
})

test_that("multiple query points return correct length", {
  set.seed(7)
  data <- matrix(rnorm(500), nrow = 100, ncol = 5)
  x    <- matrix(rnorm(50),  nrow = 10,  ncol = 5)
  d    <- spatial_depth(x, data)
  expect_length(d, 10)
})

# -----------------------------------------------------------------------------
# Deterministic — no seed needed
# -----------------------------------------------------------------------------

test_that("spatial_depth is deterministic", {
  set.seed(8)
  data <- matrix(rnorm(500), nrow = 100, ncol = 5)
  x    <- matrix(rnorm(25),  nrow = 5,   ncol = 5)
  d1   <- spatial_depth(x, data)
  d2   <- spatial_depth(x, data)
  expect_equal(d1, d2)
})

# -----------------------------------------------------------------------------
# Integration with depth object
# -----------------------------------------------------------------------------

test_that("spatial_depth works with compute_depth", {
  set.seed(9)
  data <- matrix(rnorm(500), nrow = 100, ncol = 5)
  dd   <- compute_depth(data, depth_fn = spatial_depth)
  expect_s3_class(dd, "depth")
  expect_length(dd$depths, 100)
  expect_true(all(dd$depths >= 0 & dd$depths <= 1))
})

test_that("median from spatial depth is near data center", {
  set.seed(10)
  data <- matrix(rnorm(600), nrow = 200, ncol = 3)
  dd   <- compute_depth(data, depth_fn = spatial_depth)
  m    <- median(dd)
  expect_true(sqrt(sum(m$point^2)) < 1.0)
})

test_that("outliers from spatial depth are in the tails", {
  set.seed(11)
  data <- matrix(rnorm(300), nrow = 100, ncol = 3)
  dd   <- compute_depth(data, depth_fn = spatial_depth)
  out  <- outliers(dd, threshold = 0.10)
  non_out_depths <- dd$depths[!out$outlier]
  expect_true(mean(out$depths) < mean(non_out_depths))
})
