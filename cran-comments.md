## Resubmission (0.1.8)

This is an eighth resubmission addressing feedback from Konstanze Lauseker
on 2026-06-19.

* Replaced remaining \\dontrun{} with \\donttest{} in the roxygen comment
  in src/mahalanobis_depth.cpp, which was generating \\dontrun{} in the
  auto-generated R/RcppExports.R file.

All issues from previous submissions remain fixed.

## R CMD check results

0 errors | 0 warnings | 1 note

## Notes

* NOTE: Unable to verify current time — environment issue on CRAN's check
  machines, not a package problem.

## Test environments

* Windows 11, R 4.5.3 (local)
* win-builder (R-devel)