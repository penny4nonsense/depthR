library(testthat)
library(depthR)

# -----------------------------------------------------------------------------
# Return value
# -----------------------------------------------------------------------------

test_that("dd_plot returns a data frame with correct structure", {
  set.seed(1)
  x <- matrix(rnorm(200), nrow = 100, ncol = 2)
  y <- matrix(rnorm(200), nrow = 100, ncol = 2)
  result <- dd_plot(x, y, depth_fn = mahalanobis_depth, plot = FALSE)
  expect_s3_class(result, "data.frame")
  expect_named(result, c("depth_x", "depth_y", "sample"))
  expect_equal(nrow(result), 200L)
  expect_equal(levels(result$sample), c("X", "Y"))
})

test_that("dd_plot assigns correct sample labels", {
  set.seed(2)
  x <- matrix(rnorm(100), nrow = 50, ncol = 2)
  y <- matrix(rnorm(60),  nrow = 30, ncol = 2)
  result <- dd_plot(x, y, depth_fn = mahalanobis_depth, plot = FALSE)
  expect_equal(sum(result$sample == "X"), 50L)
  expect_equal(sum(result$sample == "Y"), 30L)
})

test_that("dd_plot depth values are in valid range", {
  set.seed(3)
  x <- matrix(rnorm(200), nrow = 100, ncol = 2)
  y <- matrix(rnorm(200), nrow = 100, ncol = 2)
  result <- dd_plot(x, y, depth_fn = mahalanobis_depth, plot = FALSE)
  expect_true(all(result$depth_x >= 0))
  expect_true(all(result$depth_y >= 0))
})

# -----------------------------------------------------------------------------
# Same distribution — points near diagonal
# -----------------------------------------------------------------------------

test_that("same distribution produces depths near diagonal", {
  set.seed(4)
  x <- matrix(rnorm(400), nrow = 200, ncol = 2)
  y <- matrix(rnorm(400), nrow = 200, ncol = 2)
  result <- dd_plot(x, y, depth_fn = mahalanobis_depth, plot = FALSE)
  # For same distribution, depth_x and depth_y should be correlated
  expect_true(cor(result$depth_x, result$depth_y) > 0.5)
})

# -----------------------------------------------------------------------------
# Location shift — X points should be deeper in X than Y
# -----------------------------------------------------------------------------

test_that("location shift produces systematic off-diagonal pattern", {
  set.seed(5)
  x       <- matrix(rnorm(400), nrow = 200, ncol = 2)
  y_shift <- matrix(rnorm(400, mean = 3), nrow = 200, ncol = 2)
  result  <- dd_plot(x, y_shift, depth_fn = mahalanobis_depth, plot = FALSE)

  x_points <- result[result$sample == "X", ]
  y_points <- result[result$sample == "Y", ]

  # X points should be deeper in X than in Y on average
  expect_true(mean(x_points$depth_x) > mean(x_points$depth_y))
  # Y points should be deeper in Y than in X on average
  expect_true(mean(y_points$depth_y) > mean(y_points$depth_x))
})

# -----------------------------------------------------------------------------
# Input handling
# -----------------------------------------------------------------------------

test_that("dd_plot accepts data frames", {
  set.seed(6)
  x <- as.data.frame(matrix(rnorm(200), nrow = 100, ncol = 2))
  y <- as.data.frame(matrix(rnorm(200), nrow = 100, ncol = 2))
  result <- dd_plot(x, y, depth_fn = mahalanobis_depth, plot = FALSE)
  expect_s3_class(result, "data.frame")
})

test_that("dd_plot raises error on dimension mismatch", {
  x <- matrix(rnorm(200), nrow = 100, ncol = 2)
  y <- matrix(rnorm(300), nrow = 100, ncol = 3)
  expect_error(dd_plot(x, y, depth_fn = mahalanobis_depth, plot = FALSE))
})

test_that("dd_plot works with different depth functions", {
  set.seed(7)
  x <- matrix(rnorm(200), nrow = 100, ncol = 2)
  y <- matrix(rnorm(200), nrow = 100, ncol = 2)
  r1 <- dd_plot(x, y, depth_fn = mahalanobis_depth, plot = FALSE)
  r2 <- dd_plot(x, y, depth_fn = tukey_depth,       plot = FALSE)
  r3 <- dd_plot(x, y, depth_fn = spatial_depth,     plot = FALSE)
  expect_equal(nrow(r1), 200L)
  expect_equal(nrow(r2), 200L)
  expect_equal(nrow(r3), 200L)
})

# -----------------------------------------------------------------------------
# Plot — just check it runs without error
# -----------------------------------------------------------------------------

test_that("dd_plot produces a plot without error", {
  set.seed(8)
  x <- matrix(rnorm(200), nrow = 100, ncol = 2)
  y <- matrix(rnorm(200), nrow = 100, ncol = 2)
  expect_silent(dd_plot(x, y, depth_fn = mahalanobis_depth))
})

test_that("dd_plot with legend = FALSE runs without error", {
  set.seed(9)
  x <- matrix(rnorm(200), nrow = 100, ncol = 2)
  y <- matrix(rnorm(200), nrow = 100, ncol = 2)
  expect_silent(dd_plot(x, y, depth_fn = mahalanobis_depth, legend = FALSE))
})
