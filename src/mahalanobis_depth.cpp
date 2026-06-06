
#define EIGEN_DONT_VECTORIZE
#define EIGEN_DONT_ALIGN
#define EIGEN_DISABLE_UNALIGNED_ARRAY_ASSERT

#include <RcppEigen.h>
// [[Rcpp::depends(RcppEigen)]]

#include <cstring>

using Eigen::MatrixXd;
using Eigen::VectorXd;
using Eigen::LLT;

// Map types — zero-copy views into R memory
typedef Eigen::Map<Eigen::MatrixXd> MapMatrixXd;
typedef Eigen::Map<Eigen::VectorXd> MapVectorXd;

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

// Compute robust or classical mean vector from data matrix X (n x d)
VectorXd compute_mean(const MatrixXd& X) {
    return X.colwise().mean();
}

// Compute classical sample covariance matrix from data matrix X (n x d)
// Returns the (d x d) covariance matrix
MatrixXd compute_cov(const MatrixXd& X) {
    int n = X.rows();
    MatrixXd centered = X.rowwise() - X.colwise().mean();
    MatrixXd cov = MatrixXd::Zero(X.cols(), X.cols());
    cov.noalias() = centered.transpose() * centered;
    cov /= (double)(n - 1);
    return cov;
}

// Compute Mahalanobis depth of a single point x given mean mu and
// precision matrix (inverse covariance) sigma_inv.
// Depth = 1 / (1 + (x - mu)^T Sigma^{-1} (x - mu))
// This is a monotone decreasing function of Mahalanobis distance squared,
// mapping [0, inf) -> (0, 1], with maximum 1 at x = mu.
double mahal_depth_single(const VectorXd& x,
                          const VectorXd& mu,
                          const MatrixXd& sigma_inv) {
    VectorXd diff = x - mu;
    double dist_sq = diff.dot(sigma_inv * diff);
    return 1.0 / (1.0 + dist_sq);
}

// ---------------------------------------------------------------------------
// Exported functions
// ---------------------------------------------------------------------------

//' Mahalanobis Depth
//'
//' Computes the Mahalanobis depth of one or more query points with respect
//' to a reference distribution estimated from \code{data}.
//'
//' @details
//' Mahalanobis depth is defined as
//' \deqn{D(x, F) = \frac{1}{1 + (x - \mu)^\top \Sigma^{-1} (x - \mu)}}
//' where \eqn{\mu} and \eqn{\Sigma} are the mean vector and covariance matrix
//' of \eqn{F}, estimated from \code{data}.
//'
//' Note: The deepest point under this depth function is the mean vector, not
//' a robust generalization of the median. Mahalanobis depth is included here
//' as a computationally trivial baseline and for comparison purposes.
//' For a genuine depth function, prefer \code{simplicial_depth} or
//' \code{tukey_depth}.
//'
//' @param x Numeric matrix of query points (m x d), or a numeric vector
//'   of length d for a single query point.
//' @param data Numeric matrix of reference data (n x d). Used to estimate
//'   the mean and covariance.
//' @param mu Optional numeric vector of length d. If supplied, overrides the
//'   mean estimated from \code{data}.
//' @param sigma Optional numeric matrix (d x d). If supplied, overrides the
//'   covariance estimated from \code{data}. Must be positive definite.
//'
//' @return Numeric vector of depth values in (0, 1], one per query point.
//'   A value of 1 indicates the query point coincides with the center (mean).
//'   Values decrease toward 0 as points move away from the center.
//'
//' @examples
//' \dontrun{
//' set.seed(42)
//' data <- matrix(rnorm(200), nrow = 100, ncol = 2)
//' x    <- matrix(c(0, 0, 3, 3), nrow = 2, byrow = TRUE)
//' mahalanobis_depth(x, data)
//' }
//'
//' @keywords internal
// [[Rcpp::export(name = ".mahalanobis_depth_cpp")]]
Rcpp::NumericVector mahalanobis_depth_cpp(
        Rcpp::NumericMatrix x,
        Rcpp::NumericMatrix data,
        Rcpp::Nullable<Rcpp::NumericVector> mu    = R_NilValue,
        Rcpp::Nullable<Rcpp::NumericMatrix> sigma = R_NilValue) {

    // Map R matrices to Eigen — no copy, just a view
    MapMatrixXd X    = Rcpp::as<MapMatrixXd>(x);
    MapMatrixXd Data_map = Rcpp::as<MapMatrixXd>(data);

    int m = X.rows();   // number of query points
    int d = X.cols();   // dimension
    int n = Data_map.rows();

    // Dimension checks
    if (Data_map.cols() != d) {
        Rcpp::stop("x and data must have the same number of columns (dimension d).");
    }
    if (n <= d) {
        Rcpp::stop("data must have more rows than columns (n > d) to estimate covariance.");
    }

    // memcpy for full matrix — contiguous in column-major storage
    MatrixXd Data(n, d);
    std::memcpy(Data.data(), Data_map.data(), n * d * sizeof(double));

    // Resolve mean vector
    VectorXd mean_vec(d);
    if (mu.isNull()) {
        mean_vec = compute_mean(Data);
    } else {
        mean_vec = Rcpp::as<VectorXd>(mu);
        if (mean_vec.size() != d) {
            Rcpp::stop("mu must have length equal to the dimension d.");
        }
    }

    // Resolve covariance matrix and compute its inverse via Cholesky
    MatrixXd sigma_inv(d, d);
    if (sigma.isNull()) {
        MatrixXd S = compute_cov(Data);
        LLT<MatrixXd> llt(S);
        if (llt.info() != Eigen::Success) {
            Rcpp::stop("Covariance matrix estimated from data is not positive definite. "
                       "Check for collinear columns or supply sigma explicitly.");
        }
        sigma_inv = llt.solve(MatrixXd::Identity(d, d));
    } else {
        MatrixXd S = Rcpp::as<MatrixXd>(sigma);
        if (S.rows() != d || S.cols() != d) {
            Rcpp::stop("sigma must be a d x d matrix.");
        }
        LLT<MatrixXd> llt(S);
        if (llt.info() != Eigen::Success) {
            Rcpp::stop("Supplied sigma is not positive definite.");
        }
        sigma_inv = llt.solve(MatrixXd::Identity(d, d));
    }

    // memcpy for full matrix — contiguous in column-major storage
    // Element loop for row extraction — rows are strided, not contiguous
    Rcpp::NumericVector depths(m);
    for (int i = 0; i < m; i++) {
        VectorXd xi(d);
        for (int j = 0; j < d; j++)
            xi(j) = X(i, j);
        depths[i] = mahal_depth_single(xi, mean_vec, sigma_inv);
    }

    return depths;
}

//' Depth-Based Outlyingness
//'
//' Converts depth values to outlyingness scores via O(x) = 1/D(x) - 1,
//' so that depth 1 maps to outlyingness 0 and depth approaching 0 maps
//' to outlyingness approaching infinity.
//'
//' @param depths Numeric vector of depth values in (0, 1].
//' @return Numeric vector of outlyingness values in [0, inf).
//'
//' @export
// [[Rcpp::export]]
Rcpp::NumericVector depth_outlyingness(Rcpp::NumericVector depths) {
    int n = depths.size();
    Rcpp::NumericVector out(n);
    for (int i = 0; i < n; i++) {
        if (depths[i] <= 0.0) {
            Rcpp::stop("Depth values must be positive.");
        }
        out[i] = 1.0 / depths[i] - 1.0;
    }
    return out;
}
