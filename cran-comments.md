## R CMD check results

0 errors | 0 warnings | 3 notes

## Notes

* NOTE: Versioned LinkingTo values for RcppEigen and RcppParallel are only 
  usable in R >= 3.0.2. This is intentional — the package requires modern 
  Eigen and RcppParallel for correct parallel operation.

* NOTE: Files contain pragmas suppressing -Wignored-attributes diagnostics.
  These suppress spurious SIMD attribute warnings from Eigen on MinGW/Windows
  that are not indicative of any actual problem.

* NOTE: LICENSE file in top-level directory. This will be removed.

## Test environments

* Windows 11, R 4.5.3 (local)

## First submission

This is the first submission of depthR to CRAN.