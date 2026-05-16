## Resubmission (0.1.3)

This is a third resubmission addressing multiple issues raised by Uwe Ligges:

* The configure script now falls back to explicit -ltbb linking when
  RcppParallel::RcppParallelLibs() returns empty, which occurs on the
  CRAN Debian check system despite RcppParallel being installed.
* Reduced vignette computation time to well under CRAN's 10-minute limit
  by using smaller datasets and reduced Monte Carlo batch sizes in examples.
* Fixed GitHub URL typo in DESCRIPTION (penn4nonsense -> penny4nonsense).
* Single-quoted software names 'Rcpp' and 'RcppEigen' in DESCRIPTION per
  CRAN policy.

## R CMD check results

0 errors | 0 warnings | 4 notes

## Notes

* NOTE: Unable to verify current time — environment issue, not a package
  problem.

* NOTE: Versioned LinkingTo values for RcppEigen and RcppParallel are only
  usable in R >= 3.0.2. This is intentional — the package requires modern
  Eigen and RcppParallel for correct parallel operation.

* NOTE: cran-comments.md at top level — listed in .Rbuildignore and not
  included in the package tarball.

* NOTE: Pragmas suppressing -Wignored-attributes in C++ files. These suppress
  spurious SIMD attribute warnings from Eigen on MinGW/Windows that are not
  indicative of any actual problem.

## Test environments

* Windows 11, R 4.3.1 (local)
* win-builder (R-devel)