# depthR

**Multivariate depth functions for general dimension.**

depthR provides efficient, general-purpose implementations of statistical depth
functions in arbitrary dimension d. The goal is to make depth-based inference
— robust location, outlier detection, multivariate ranks, depth-based quantile
regions — actually usable by any R user, at any reasonable d and n.

Existing R packages for depth (ddalpha, depth, DepthProc) cap out at low
dimension or are too slow for practical use at large d. depthR uses C++
backends via RcppEigen to remove that barrier.

## Depth Functions (Planned)

| Function | Status | Notes |
|---|---|---|
| Mahalanobis | ✅ v0.1 | Baseline; deepest point is the mean |
| Simplicial (Liu 1990) | 🔧 next | Adaptive Monte Carlo; the main event |
| Tukey (Halfspace) | 📋 planned | Random projection approximation for large d |
| Projection (Zuo & Serfling 2000) | 📋 planned | |
| Spatial | 📋 planned | Gradient-friendly, good for high d |

## Installation

```r
# Development version
devtools::install_github("yourname/depthR")
```

## Quick Start

```r
library(depthR)

set.seed(42)
data <- matrix(rnorm(1000), nrow = 200, ncol = 5)
x    <- matrix(rnorm(25),   nrow = 5,   ncol = 5)

# Depth of query points
mahalanobis_depth(x, data)

# Depth-based median
depth_median(data)

# Outlyingness (inverse of depth)
d   <- mahalanobis_depth(x, data)
out <- depth_outlyingness(d)
```

## References

- Liu, R. Y. (1990). On a notion of data depth based on random simplices.
  *Annals of Statistics*, 18(1), 405–414.
- Zuo, Y. & Serfling, R. (2000). General notions of statistical depth function.
  *Annals of Statistics*, 28(2), 461–482.
- Serfling, R. (2006). Depth functions in nonparametric multivariate inference.
  *DIMACS Series in Discrete Mathematics*, 72, 1–16.
