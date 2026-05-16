## Resubmission (0.1.2)

This is a second resubmission addressing the Debian installation failure.

* Replaced src/Makevars $(shell ...) with a configure script that generates
  src/Makevars at build time via RcppParallel::RcppParallelLibs(). This
  eliminates both the GNU extensions warning and the Debian linking failure.
* Added cleanup script to remove the generated src/Makevars after build.
* src/Makevars.win handles Windows-specific flags without GNU extensions.
* Updated RoxygenNote to 8.0.0.

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