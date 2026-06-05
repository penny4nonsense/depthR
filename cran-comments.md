## Resubmission (0.1.5)

This is a fifth resubmission. The root cause of the persistent Debian
installation failure has been identified and fixed.

RcppParallel ships its own bundled TBB and loads it dynamically at runtime
on Linux — no compile-time TBB linking is needed or correct. Previous
attempts to link -ltbb were linking against the system TBB, which has an
incompatible ABI with RcppParallel's bundled version. This was confirmed
by reading RcppParallel's source code, which documents explicitly that
LdFlags() returns empty on Linux by design.

The following changes have been made:

* configure script now calls RcppParallel::LdFlags() instead of
  RcppParallelLibs(). On Linux this returns empty (correct — no compile-time
  TBB linking needed). On Windows it returns the proper TBB link flags.
* Added importFrom(RcppParallel, RcppParallelLibs) to NAMESPACE to ensure
  RcppParallel is loaded before depthR, which triggers dynamic TBB loading
  at runtime on Linux.
* Added RcppParallel to Imports in DESCRIPTION to enforce correct load order.

All issues from previous submissions remain fixed:

* Monte Carlo vignette chunks are eval = FALSE with pre-computed static output.
* skip_on_cran() added to all slow test files.
* GitHub URL corrected.
* Software names single-quoted in DESCRIPTION.

## R CMD check results

0 errors | 0 warnings | 4 notes

## Notes

* NOTE: Unable to verify current time — environment issue, not a package
  problem.
* NOTE: Versioned LinkingTo values for RcppEigen and RcppParallel are only
  usable in R >= 3.0.2. This is intentional.
* NOTE: cran-comments.md at top level — listed in .Rbuildignore and not
  included in the package tarball.
* NOTE: Pragmas suppressing -Wignored-attributes in C++ files. These suppress
  spurious SIMD attribute warnings from Eigen on MinGW/Windows.

## Test environments

* Windows 11, R 4.5.3 (local)
* win-builder (R-devel)