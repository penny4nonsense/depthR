# depthR 0.1.3

* Fixed Debian/Linux linking failure by adding fallback to explicit -ltbb
  linking in configure script when RcppParallel::RcppParallelLibs() returns
  empty.

# depthR 0.1.2

* Fixed Linux/Debian installation failure by replacing src/Makevars $(shell ...)
  with a configure script that generates src/Makevars at build time.
* Added cleanup script to remove generated src/Makevars after build.
* Updated RoxygenNote to 8.0.0.

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