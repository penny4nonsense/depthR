#ifdef __GNUC__
#pragma GCC diagnostic ignored "-Wignored-attributes"
#endif

#define EIGEN_DONT_VECTORIZE
#define EIGEN_DONT_ALIGN
#define EIGEN_DISABLE_UNALIGNED_ARRAY_ASSERT

#include <RcppEigen.h>
#include <RcppParallel.h>
// [[Rcpp::depends(RcppEigen)]]
// [[Rcpp::depends(RcppParallel)]]

#include <cmath>
#include <cstring>
#include <vector>

using Eigen::MatrixXd;
using Eigen::VectorXd;

typedef Eigen::Map<Eigen::MatrixXd> MapMatrixXd;

// =============================================================================
// Spatial depth
//
// SD(x, F) = 1 - || E[ (x - X) / ||x - X|| ] ||
//
// where the expectation is over X ~ F. Estimated by the sample mean of
// unit vectors pointing from each data point toward x.
//
// Unlike Tukey, simplicial, and projection depth, spatial depth has a
// closed-form sample estimate — no Monte Carlo needed. For each query
// point x we simply compute the mean of the unit vectors (x - x_i) / ||x - x_i||
// over all data points x_i, then take 1 - norm of that mean vector.
//
// Points exactly coinciding with a data point are handled by skipping
// that data point (the unit vector is undefined there).
//
// Parallelism: we parallelize over data points for each query point.
// Each thread accumulates a partial sum of unit vectors, then we reduce.
// =============================================================================

// =============================================================================
// RcppParallel Worker
// =============================================================================

struct SpatialWorker : public RcppParallel::Worker {

    const MatrixXd& data;
    const VectorXd& x;
    int n;
    int d;

    // Per-slot partial sums — each thread writes to its own slot
    // We store d-dimensional partial sums flattened: slot i owns
    // rows [i*d .. (i+1)*d) of a flat vector
    std::vector<double> partial_sums;
    std::vector<int>    partial_counts;

    SpatialWorker(const MatrixXd& data_,
                  const VectorXd& x_,
                  int n_slots)
        : data(data_),
          x(x_),
          n(data_.rows()),
          d(data_.cols()),
          partial_sums(n_slots * data_.cols(), 0.0),
          partial_counts(n_slots, 0)
    {}

    void operator()(std::size_t begin, std::size_t end) {
        VectorXd sum(d);
        sum.setZero();
        int count = 0;

        for (std::size_t i = begin; i < end; i++) {
            // Compute x - data[i]
            VectorXd diff(d);
            for (int j = 0; j < d; j++)
                diff(j) = x(j) - data(i, j);

            double norm_val = diff.norm();

            // Skip if x coincides with data point
            if (norm_val < 1e-10) continue;

            sum += diff / norm_val;
            count++;
        }

        // Write partial sum to this thread's slot
        int slot = (int)begin;
        for (int j = 0; j < d; j++)
            partial_sums[slot * d + j] = sum(j);
        partial_counts[slot] = count;
    }
};

// =============================================================================
// Compute spatial depth for a single query point
// =============================================================================

double spatial_depth_single(const MatrixXd& data,
                             const VectorXd& x) {
    int n = data.rows();
    int d = data.cols();

    // Parallelize over data points — each thread handles a range of rows
    // We use n as the parallelFor range and n slots in the worker
    SpatialWorker worker(data, x, n);
    RcppParallel::parallelFor(0, n, worker);

    // Reduce partial sums across all slots
    VectorXd total_sum(d);
    total_sum.setZero();
    int total_count = 0;

    for (int slot = 0; slot < n; slot++) {
        if (worker.partial_counts[slot] > 0) {
            for (int j = 0; j < d; j++)
                total_sum(j) += worker.partial_sums[slot * d + j];
            total_count += worker.partial_counts[slot];
        }
    }

    if (total_count == 0) return 0.0;

    // Mean unit vector
    VectorXd mean_vec = total_sum / (double)total_count;

    // Spatial depth = 1 - ||mean unit vector||
    return 1.0 - mean_vec.norm();
}

// =============================================================================
// Exported function
// =============================================================================

//' Spatial Depth
//'
//' Computes the spatial depth of one or more query points with respect
//' to a reference distribution estimated from \code{data}.
//'
//' @details
//' Spatial depth is defined as:
//' \deqn{SD(x, F) = 1 - \left\| E\left[ \frac{x - X}{\|x - X\|} \right] \right\|}
//' where the expectation is over \eqn{X \sim F}. It is estimated by the
//' sample mean of unit vectors pointing from each data point toward x.
//'
//' Unlike other depth functions in this package, spatial depth has a
//' closed-form sample estimate and requires no Monte Carlo approximation.
//' This makes it extremely fast even at large n and d.
//'
//' Spatial depth is not affine invariant but is orthogonally invariant,
//' and has been found to work well in high dimensions where affine
//' invariant methods can be computationally prohibitive.
//'
//' @param x Numeric matrix of query points (m x d), or a numeric vector
//'   of length d for a single query point.
//' @param data Numeric matrix of reference data (n x d).
//'
//' @return Numeric vector of depth values in [0, 1], one per query point.
//'   A value of 1 indicates perfect centrality (the spatial median).
//'   Values decrease toward 0 as points move away from the center.
//'
//' @references
//' Vardi, Y. & Zhang, C.-H. (2000). The multivariate L1-median and
//' associated data depth. \emph{Proceedings of the National Academy of
//' Sciences}, 97(4), 1423--1426.
//'
//' Serfling, R. (2006). Depth functions in nonparametric multivariate
//' inference. \emph{DIMACS Series in Discrete Mathematics}, 72, 1--16.
//'
//' @keywords internal
// [[Rcpp::export(name = ".spatial_depth_cpp")]]
Rcpp::NumericVector spatial_depth_cpp(
    Rcpp::NumericMatrix x,
    Rcpp::NumericMatrix data) {

    MapMatrixXd X_map    = Rcpp::as<MapMatrixXd>(x);
    MapMatrixXd Data_map = Rcpp::as<MapMatrixXd>(data);

    int m      = X_map.rows();
    int d      = X_map.cols();
    int n_data = Data_map.rows();

    if (Data_map.cols() != d)
        Rcpp::stop("x and data must have the same number of columns.");
    if (n_data < 2)
        Rcpp::stop("data must have at least 2 rows.");

    // memcpy for full matrix — contiguous in column-major storage
    MatrixXd Data(n_data, d);
    std::memcpy(Data.data(), Data_map.data(), n_data * d * sizeof(double));

    Rcpp::NumericVector depths(m);

    for (int i = 0; i < m; i++) {
        VectorXd xi(d);
        for (int j = 0; j < d; j++)
            xi(j) = X_map(i, j);
        depths[i] = spatial_depth_single(Data, xi);
    }

    return depths;
}
