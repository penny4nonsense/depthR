## Resubmission (0.1.4)

This is a fourth resubmission. I have been extra careful this time to ensure
the check time issue is fully resolved.

The previous timeout was caused by developing on a 32-core Threadripper where
RcppParallel distributes Monte Carlo iterations across all cores, making the
vignette appear fast locally while running for 100+ minutes on a single-core
check machine.

The following changes have been made:

* Set eval = FALSE on all Monte Carlo vignette chunks (Tukey, simplicial,
  projection depth) and replaced with pre-computed static output. Only
  closed-form functions (Mahalanobis, spatial) now execute during check.
  The vignette was verified to build in under 5 seconds locally after
  these changes.
* Fixed Debian/Linux linking failure by adding -ltbb fallback in the
  configure script.
* Fixed GitHub URL typo in DESCRIPTION (penn4nonsense -> penny4nonsense).
* Single-quoted 'Rcpp' and 'RcppEigen' in DESCRIPTION per CRAN policy.