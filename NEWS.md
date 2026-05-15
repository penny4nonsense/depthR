# depthR 0.1.1

* Fixed Debian/Linux installation failure due to missing RcppParallel 
  linker flags in src/Makevars.
* Added src/Makevars.win for Windows-specific build configuration.
* Fixed GitHub URL in DESCRIPTION.
* Quoted technical terms in DESCRIPTION per CRAN policy.

# depthR 0.1.0

* Initial release to CRAN.
* Implements five multivariate depth functions: Mahalanobis, Tukey 
  (halfspace), Liu simplicial, projection, and spatial depth.
* All functions work in arbitrary dimension d with C++ backends via 
  RcppEigen and RcppParallel.
* Includes depth-based median, ranks, outlier detection, central regions,
  and DD-plots via the compute_depth() S3 infrastructure.