# depthR 0.1.5

* Fixed Debian/Linux installation failure. Root cause identified: RcppParallel
  ships its own bundled TBB and loads it dynamically at runtime on Linux —
  no compile-time TBB linking is needed or correct. Previous -ltbb fallback
  was linking against system TBB which has an incompatible ABI with
  RcppParallel's bundled version.
* configure script now calls RcppParallel::LdFlags() which returns empty on
  Linux by design, allowing RcppParallel to handle TBB loading dynamically.
* Added importFrom(RcppParallel, RcppParallelLibs) to NAMESPACE to ensure
  RcppParallel is loaded before depthR, triggering dynamic TBB loading.
* Added RcppParallel to Imports in DESCRIPTION to enforce correct load order.

# depthR 0.1.4

* Set eval = FALSE on all Monte Carlo vignette chunks (Tukey, simplicial,
  and projection depth) and replaced with pre-computed static output. Only
  closed-form functions (Mahalanobis and spatial depth) now execute during
  check. This resolves the Windows check timeout caused by developing on a
  multi-core machine where RcppParallel masked the true single-core runtime.
* Added skip_on_cran() to test files for Monte Carlo depth functions
  (Tukey, simplicial, projection) and DD-plot to prevent test suite
  timeout on CRAN check machines.
* Fixed GitHub URL typo in DESCRIPTION (penn4nonsense -> penny4nonsense).
* Single-quoted 'Rcpp' and 'RcppEigen' in DESCRIPTION per CRAN policy.

# depthR 0.1.3

* Fixed Debian/Linux linking failure by adding fallback to explicit -ltbb
  linking in configure script when RcppParallel::RcppParallelLibs() returns
  empty.
* Reduced vignette computation time to comply with CRAN's 10-minute check
  limit. Monte Carlo depth functions now use smaller batch sizes and datasets
  in vignette examples.
  
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