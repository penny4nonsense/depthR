library(testthat)
library(depthR)

test_that("mahalanobis_depth returns values in (0, 1]", {
  set.seed(1)
  data <- matrix(rnorm(300), nrow = 100, ncol = 3)
  x    <- matrix(rnorm(15),  nrow = 5,   ncol = 3)
  d    <- mahalanobis_depth(x, data)
  expect_true(all(d > 0))
  expect_true(all(d <= 1))
})

test_that("deepest point is at or near the mean", {
  set.seed(2)
  data <- matrix(rnorm(200), nrow = 100, ncol = 2)
  mu   <- colMeans(data)
  d_at_mean  <- mahalanobis_depth(matrix(mu, nrow = 1), data)
  d_at_other <- mahalanobis_depth(matrix(mu + 3, nrow = 1), data)
  expect_equal(d_at_mean, 1.0, tolerance = 1e-10)
  expect_true(d_at_mean > d_at_other)
})

test_that("depth decreases as point moves away from center", {
  set.seed(3)
  data <- matrix(rnorm(2000), nrow = 400, ncol = 5)
  mu   <- colMeans(data)
  # Points at increasing distance from mean along first axis
  offsets <- c(0, 1, 2, 4, 8)
  pts <- t(sapply(offsets, function(o) { v <- mu; v[1] <- v[1] + o; v }))
  depths <- mahalanobis_depth(pts, data)
  expect_true(all(diff(depths) < 0))
})

test_that("single vector input is handled correctly", {
  set.seed(4)
  data <- matrix(rnorm(200), nrow = 100, ncol = 2)
  x    <- c(0.0, 0.0)
  d    <- mahalanobis_depth(x, data)
  expect_length(d, 1)
  expect_true(d > 0 && d <= 1)
})

test_that("user-supplied mu and sigma are respected", {
  set.seed(5)
  data  <- matrix(rnorm(200), nrow = 100, ncol = 2)
  mu    <- c(0, 0)
  sigma <- diag(2)
  x     <- matrix(c(0, 0), nrow = 1)
  d     <- mahalanobis_depth(x, data, mu = mu, sigma = sigma)
  expect_equal(d, 1.0, tolerance = 1e-10)
})

test_that("depth_outlyingness inverts depth correctly", {
  depths <- c(1.0, 0.5, 0.25)
  out    <- depth_outlyingness(depths)
  expect_equal(out, c(0.0, 1.0, 3.0), tolerance = 1e-10)
})

test_that("median.depth returns a list with correct structure", {
  set.seed(6)
  data   <- matrix(rnorm(200), nrow = 100, ncol = 2)
  dd     <- compute_depth(data, depth_fn = mahalanobis_depth)
  result <- median(dd)
  expect_named(result, c("point", "depth", "index"))
  expect_length(result$point, 2)
  expect_true(result$depth > 0 && result$depth <= 1)
  expect_true(result$index >= 1 && result$index <= 100)
})

test_that("dimension mismatch raises an error", {
  data <- matrix(rnorm(200), nrow = 100, ncol = 2)
  x    <- matrix(rnorm(15),  nrow = 5,   ncol = 3)   # wrong d
  expect_error(mahalanobis_depth(x, data))
})

test_that("n <= d raises an error", {
  data <- matrix(rnorm(4), nrow = 2, ncol = 2)   # n == d, not n > d
  x    <- matrix(c(0, 0), nrow = 1)
  expect_error(mahalanobis_depth(x, data))
})
