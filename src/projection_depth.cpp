
#define EIGEN_DONT_VECTORIZE
#define EIGEN_DONT_ALIGN
#define EIGEN_DISABLE_UNALIGNED_ARRAY_ASSERT

#include <RcppEigen.h>
#include <RcppParallel.h>
// [[Rcpp::depends(RcppEigen)]]
// [[Rcpp::depends(RcppParallel)]]

#include <algorithm>
#include <cmath>
#include <cstring>
#include <random>
#include <vector>

using Eigen::MatrixXd;
using Eigen::VectorXd;

typedef Eigen::Map<Eigen::MatrixXd> MapMatrixXd;

// =============================================================================
// Internal helpers
// =============================================================================

inline VectorXd random_unit_vector(int d, std::mt19937& rng) {
    std::normal_distribution<double> norm(0.0, 1.0);
    VectorXd v(d);
    for (int i = 0; i < d; i++)
        v(i) = norm(rng);
    double norm_val = v.norm();
    if (norm_val < 1e-10) {
        v(0) = 1.0;
        return v;
    }
    return v / norm_val;
}

// Compute median of a sorted vector
inline double sorted_median(const std::vector<double>& sorted_v) {
    int n = sorted_v.size();
    if (n % 2 == 1)
        return sorted_v[n / 2];
    return 0.5 * (sorted_v[n / 2 - 1] + sorted_v[n / 2]);
}

// Compute outlyingness of x_proj given sorted projected data.
// Returns the robust Z-score: |x_proj - median| / MAD
// Returns -1.0 if MAD is zero (caller should skip this projection)
inline double projection_outlyingness(const std::vector<double>& sorted_proj,
                                       double x_proj) {
    int n = sorted_proj.size();
    double med = sorted_median(sorted_proj);

    // Compute MAD — median of |proj_i - med|
    std::vector<double> abs_dev(n);
    for (int i = 0; i < n; i++)
        abs_dev[i] = std::abs(sorted_proj[i] - med);
    std::sort(abs_dev.begin(), abs_dev.end());
    double mad = sorted_median(abs_dev);

    // Guard against zero MAD
    if (mad < 1e-10) return -1.0;

    return std::abs(x_proj - med) / mad;
}

// =============================================================================
// RcppParallel Worker
// =============================================================================

struct ProjectionWorker : public RcppParallel::Worker {

    const MatrixXd& data;
    const VectorXd& x;
    int batch_size;
    unsigned int base_seed;

    // Per-slot maximum outlyingness — one slot per projection in batch
    std::vector<double> local_max;

    ProjectionWorker(const MatrixXd& data_,
                     const VectorXd& x_,
                     int batch_size_,
                     unsigned int base_seed_)
        : data(data_),
          x(x_),
          batch_size(batch_size_),
          base_seed(base_seed_),
          local_max(batch_size_, 0.0)
    {}

    void operator()(std::size_t begin, std::size_t end) {
        int d = data.cols();
        int n = data.rows();

        std::mt19937 rng(base_seed + (unsigned int)begin);
        std::vector<double> proj_data(n);
        double thread_max = 0.0;

        for (std::size_t idx = begin; idx < end; idx++) {
            VectorXd u = random_unit_vector(d, rng);

            // Project all data points
            VectorXd projections = data * u;
            for (int i = 0; i < n; i++)
                proj_data[i] = projections(i);
            std::sort(proj_data.begin(), proj_data.end());

            // Project query point
            double x_proj = x.dot(u);

            // Compute outlyingness for this projection
            double out = projection_outlyingness(proj_data, x_proj);

            // Skip if MAD was zero
            if (out < 0.0) continue;

            thread_max = std::max(thread_max, out);
        }

        // Write thread maximum to all slots in this range
        for (std::size_t idx = begin; idx < end; idx++)
            local_max[idx] = thread_max;
    }
};

// =============================================================================
// Adaptive stopping rule
//
// We're estimating a supremum — same situation as Tukey depth.
// Use patience/stability: stop when the running maximum hasn't changed
// by more than tol (relative) over 'patience' consecutive batches.
// =============================================================================

double projection_depth_single_adaptive(const MatrixXd& data,
                                         const VectorXd& x,
                                         int batch_size,
                                         int min_batches,
                                         int patience,
                                         double tol,
                                         unsigned int seed) {
    double current_max  = 0.0;
    double prev_max     = 0.0;
    int    stable_count = 0;
    int    batch_num    = 0;

    while (true) {
        unsigned int batch_seed = seed + (unsigned int)(batch_num * batch_size);

        ProjectionWorker worker(data, x, batch_size, batch_seed);
        RcppParallel::parallelFor(0, batch_size, worker);

        // Reduce — global maximum across all threads
        double batch_max = *std::max_element(worker.local_max.begin(),
                                              worker.local_max.end());
        current_max = std::max(current_max, batch_max);
        batch_num++;

        if (batch_num < min_batches) {
            prev_max = current_max;
            continue;
        }

        // Stopping rule: has the maximum stabilised?
        double change = std::abs(current_max - prev_max);
        double relative_change = (prev_max > 1e-10)
                                    ? change / prev_max
                                    : change;

        if (relative_change < tol) {
            stable_count++;
        } else {
            stable_count = 0;
        }

        prev_max = current_max;

        if (stable_count >= patience) break;
        if (batch_num >= 500)        break;
    }

    // Convert outlyingness to depth
    return 1.0 / (1.0 + current_max);
}

// =============================================================================
// Exported function
// =============================================================================

//' Projection Depth
//'
//' Computes the projection depth of one or more query points with respect
//' to a reference distribution estimated from \code{data}, using an adaptive
//' random projection approximation.
//'
//' @details
//' Projection depth is defined via the Stahel-Donoho outlyingness measure:
//' \deqn{O(x, F) = \sup_{u \neq 0} \frac{|u^\top x - \mathrm{med}(u^\top F)|}
//'                                        {\mathrm{MAD}(u^\top F)}}
//' \deqn{PD(x, F) = \frac{1}{1 + O(x, F)}}
//' where med and MAD are the median and median absolute deviation of the
//' projected distribution. The supremum is approximated by the maximum over
//' random unit vector projections.
//'
//' @param x Numeric matrix of query points (m x d), or a numeric vector
//'   of length d for a single query point.
//' @param data Numeric matrix of reference data (n x d).
//' @param tol Convergence tolerance for the adaptive stopping rule. Default
//'   0.01.
//' @param batch_size Number of random projections per batch. Default 100.
//' @param min_batches Minimum batches before checking convergence. Default 5.
//' @param patience Consecutive stable batches required to declare convergence.
//'   Default 3.
//' @param seed Integer random seed for reproducibility. Default 42.
//'
//' @return Numeric vector of depth values in (0, 1], one per query point.
//'
//' @references
//' Zuo, Y. & Serfling, R. (2000). General notions of statistical depth
//' function. \emph{Annals of Statistics}, 28(2), 461--482.
//'
//' Stahel, W. A. (1981). Robuste Schätzungen: infinitesimale Optimalität
//' und Schätzungen von Kovarianzmatrizen. PhD thesis, ETH Zürich.
//'
//' @keywords internal
// [[Rcpp::export(name = ".projection_depth_cpp")]]
Rcpp::NumericVector projection_depth_cpp(
    Rcpp::NumericMatrix x,
    Rcpp::NumericMatrix data,
    double tol        = 0.01,
    int batch_size    = 100,
    int min_batches   = 5,
    int patience      = 3,
    int seed          = 42) {

    MapMatrixXd X_map    = Rcpp::as<MapMatrixXd>(x);
    MapMatrixXd Data_map = Rcpp::as<MapMatrixXd>(data);

    int m      = X_map.rows();
    int d      = X_map.cols();
    int n_data = Data_map.rows();

    if (Data_map.cols() != d)
        Rcpp::stop("x and data must have the same number of columns.");
    if (n_data < 2)
        Rcpp::stop("data must have at least 2 rows.");
    if (tol <= 0.0 || tol >= 1.0)
        Rcpp::stop("tol must be in (0, 1).");
    if (batch_size < 1)
        Rcpp::stop("batch_size must be >= 1.");
    if (patience < 1)
        Rcpp::stop("patience must be >= 1.");

    // memcpy for full matrix — contiguous in column-major storage
    MatrixXd Data(n_data, d);
    std::memcpy(Data.data(), Data_map.data(), n_data * d * sizeof(double));

    Rcpp::NumericVector depths(m);

    for (int i = 0; i < m; i++) {
        VectorXd xi(d);
        for (int j = 0; j < d; j++)
            xi(j) = X_map(i, j);
        unsigned int point_seed = (unsigned int)seed + (unsigned int)(i * 10000);
        depths[i] = projection_depth_single_adaptive(
            Data, xi,
            batch_size, min_batches, patience, tol,
            point_seed
        );
    }

    return depths;
}
