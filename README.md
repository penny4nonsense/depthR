# depthR

**Multivariate depth functions for general dimension.**

depthR provides efficient, general-purpose implementations of statistical depth
functions in arbitrary dimension d. The goal is to make depth-based inference
— robust location, outlier detection, multivariate ranks, depth-based quantile
regions — actually usable by any R user, at any reasonable d and n.

Existing R packages for depth (ddalpha, depth, DepthProc) cap out at low
dimension or are too slow for practical use at large d. depthR uses C++
backends via RcppEigen and RcppParallel to remove that barrier.

## Depth Functions

| Function | Notes |
|---|---|
| `mahalanobis_depth()` | Baseline; deepest point is the mean |
| `tukey_depth()` | Halfspace depth; adaptive random projection approximation |
| `simplicial_depth()` | Liu (1990); adaptive Monte Carlo with Bernoulli stopping rule |
| `projection_depth()` | Stahel-Donoho outlyingness; robust and affine invariant |
| `spatial_depth()` | Closed-form estimate; fastest option for large n and d |

## Installation

```r
# From CRAN
install.packages("depthR")

# Development version
devtools::install_github("penny4nonsense/depthR")
```

## Quick Start

```r
library(depthR)
set.seed(42)
data <- matrix(rnorm(1000), nrow = 200, ncol = 5)

# Compute depth once — derive everything else cheaply
dd <- compute_depth(data, depth_fn = simplicial_depth)

# Depth-based median — robust multivariate location estimate
median(dd)

# Depth-based ranks — rank 1 is the deepest point
head(rank(dd))

# Outlier detection — bottom 5% by depth
outliers(dd, threshold = 0.05)

# Central region — inner 50% of data
central_region(dd, alpha = 0.50)

# Plot — outliers flagged in red
plot(dd)
```

## DD-Plot

The depth-depth plot is the multivariate analog of the QQ-plot, useful for
two-sample comparison:

```r
x <- matrix(rnorm(400), nrow = 200, ncol = 2)
y <- matrix(rnorm(400, mean = 2), nrow = 200, ncol = 2)
dd_plot(x, y, depth_fn = tukey_depth)
```

## References

- Liu, R. Y. (1990). On a notion of data depth based on random simplices.
  *Annals of Statistics*, 18(1), 405–414.
- Vardi, Y. & Zhang, C.-H. (2000). The multivariate L1-median and associated
  data depth. *PNAS*, 97(4), 1423–1426.
- Zuo, Y. & Serfling, R. (2000). General notions of statistical depth function.
  *Annals of Statistics*, 28(2), 461–482.
- Serfling, R. (2006). Depth functions in nonparametric multivariate inference.
  *DIMACS Series in Discrete Mathematics*, 72, 1–16.
