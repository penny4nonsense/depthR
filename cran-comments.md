## Resubmission

This is a resubmission. The following issues from the initial review have been addressed:

* Fixed Debian/Linux installation failure caused by missing RcppParallel
  linker flags. Updated src/Makevars to use portable
  `"${R_HOME}/bin/Rscript"` syntax for RcppParallel::RcppParallelLibs().
* Added src/Makevars.win for Windows-specific build configuration without
  GNU extensions.
* Fixed GitHub URL (repository is now public).
* Added cran-comments.md to .Rbuildignore.
* Quoted technical terms in DESCRIPTION (Liu, Rcpp, RcppEigen, halfspace,
  simplicial, backends).

## R CMD check results

0 errors | 1 warning | 3 notes

## Warning

* WARNING: GNU extensions in src/Makevars ($(shell ...)).
  The src/Makevars file uses $(shell ...) to obtain RcppParallel linker
  flags dynamically via RcppParallel::RcppParallelLibs(). This is the
  approach recommended by the RcppParallel package documentation and is
  necessary for correct linking on Linux and macOS. The src/Makevars.win
  file used on Windows does not use GNU extensions. This pattern is used
  by many CRAN packages that depend on RcppParallel.

## Notes

* NOTE: Versioned LinkingTo values for RcppEigen and RcppParallel are only
  usable in R >= 3.0.2. This is intentional — the package requires modern
  Eigen and RcppParallel for correct parallel operation.

* NOTE: Pragmas suppressing -Wignored-attributes in C++ files. These suppress
  spurious SIMD attribute warnings from Eigen on MinGW/Windows that are not
  indicative of any actual problem.

* NOTE: cran-comments.md at top level. This file is listed in .Rbuildignore
  and is not included in the package tarball.

## Test environments

* Windows 11, R 4.5.3 (local)
* win-builder (R-devel)

## Resubmission notes

This is the first CRAN release of depthR.