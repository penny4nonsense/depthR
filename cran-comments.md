## Resubmission (0.1.6)

This is a sixth resubmission addressing feedback from Uwe Ligges on 2026-06-05.

The following changes have been made:

* Removed #pragma GCC diagnostic suppression from all C++ source files.
* Updated Date field in DESCRIPTION to 2026-06-05.
* Added Depends: R (>= 3.1.0) to DESCRIPTION to address versioned LinkingTo
  note.
* Added cran-comments.md to .Rbuildignore to exclude from package tarball.

All issues from previous submissions remain fixed:

* Debian/Linux installation failure resolved — RcppParallel::LdFlags() used
  in configure script; RcppParallel added to Imports for correct load order.
* Monte Carlo vignette chunks are eval = FALSE with pre-computed static output.
* skip_on_cran() added to all slow test files.
* GitHub URL corrected.
* Software names single-quoted in DESCRIPTION.

## R CMD check results

0 errors | 0 warnings | 0 notes (local)

## Notes

No notes on local check. CRAN's automated checker may show notes for:

* Versioned LinkingTo values for RcppEigen and RcppParallel — addressed by
  adding Depends: R (>= 3.1.0).
* Unable to verify current time — environment issue on CRAN's check machines,
  not a package problem.

## Test environments

* Windows 11, R 4.5.3 (local)
* win-builder (R-devel)
