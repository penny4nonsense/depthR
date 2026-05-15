# depthR 0.1.0

* Initial release to CRAN.
* Implements five multivariate depth functions: Mahalanobis, Tukey 
  (halfspace), Liu simplicial, projection, and spatial depth.
* All functions work in arbitrary dimension d with C++ backends via 
  RcppEigen and RcppParallel.
* Includes depth-based median, ranks, outlier detection, central regions,
  and DD-plots via the `compute_depth()` S3 infrastructure.