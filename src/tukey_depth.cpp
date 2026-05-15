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

#include <algorithm>
#include <cmath>
#include <cstring>
#include <limits>
#include <random>
#include <vector>

using Eigen::MatrixXd;
using Eigen::VectorXd;

typedef Eigen::Map<Eigen::MatrixXd> MapMatrixXd;
typedef Eigen::Map<Eigen::VectorXd> MapVectorXd;

// =============================================================================
// Internal helpers
// =============================================================================

inline VectorXd random_unit_vector(int d, std::mt19937& rng) {
    std::normal_distribution<double> norm(0.0, 1.0);
    VectorXd v(d);
    for (int i = 0; i < d; i++) {
        v(i) = norm(rng);
    }
    double norm_val = v.norm();
    if (norm_val < 1e-10) {
        v(0) = 1.0;
        return v;
    }
    return v / norm_val;
}

inline double halfspace_depth_1d(const std::vector<double>& proj_data,
                                  double x_proj) {
    int n = proj_data.size();
    int below = (int)(std::upper_bound(proj_data.begin(),
                                        proj_data.end(),
                                        x_proj) - proj_data.begin());
    double prop_below = (double)below / (double)n;
    double prop_above = 1.0 - (double)(below - 1) / (double)n;
    prop_above = std::min(1.0, std::max(0.0, prop_above));
    return std::min(prop_below, prop_above);
}

// =============================================================================
// RcppParallel Worker
// Data and x are owned MatrixXd/VectorXd (not Maps) so heap allocation
// is handled by standard new/delete, not R's allocator — safe for TBB
// =============================================================================

struct TukeyWorker : public RcppParallel::Worker {

    const MatrixXd& data;
    const VectorXd& x;
    int batch_size;
    unsigned int base_seed;
    std::vector<double> local_mins;

    TukeyWorker(const MatrixXd& data_,
                const VectorXd& x_,
                int batch_size_,
                unsigned int base_seed_)
        : data(data_),
          x(x_),
          batch_size(batch_size_),
          base_seed(base_seed_),
          local_mins(batch_size_, 1.0)
    {}

    void operator()(std::size_t begin, std::size_t end) {
        int d = data.cols();
        int n = data.rows();

        // Each thread gets its own RNG seeded uniquely
        std::mt19937 rng(base_seed + (unsigned int)begin);
        std::vector<double> proj_data(n);
        double local_min = 1.0;

        for (std::size_t idx = begin; idx < end; idx++) {
            VectorXd u = random_unit_vector(d, rng);
            VectorXd projections = data * u;
            for (int i = 0; i < n; i++) {
                proj_data[i] = projections(i);
            }
            std::sort(proj_data.begin(), proj_data.end());
            double x_proj = x.dot(u);
            double depth  = halfspace_depth_1d(proj_data, x_proj);
            local_min = std::min(local_min, depth);
        }

        for (std::size_t idx = begin; idx < end; idx++) {
            local_mins[idx] = local_min;
        }
    }
};

// =============================================================================
// Adaptive stopping rule
// =============================================================================

double tukey_depth_single_adaptive(const MatrixXd& data,
                                    const VectorXd& x,
                                    int batch_size,
                                    int min_batches,
                                    int patience,
                                    double tol,
                                    unsigned int seed) {
    double current_min  = 1.0;
    double prev_min     = 1.0;
    int    stable_count = 0;
    int    batch_num    = 0;

    while (true) {
        TukeyWorker worker(data, x, batch_size,
                           seed + (unsigned int)(batch_num * batch_size));
        RcppParallel::parallelFor(0, batch_size, worker);

        double batch_min = *std::min_element(worker.local_mins.begin(),
                                              worker.local_mins.end());
        current_min = std::min(current_min, batch_min);
        batch_num++;

        if (batch_num < min_batches) {
            prev_min = current_min;
            continue;
        }

        double change = std::abs(prev_min - current_min);
        double relative_change = (prev_min > 1e-10)
                                    ? change / prev_min
                                    : change;

        if (relative_change < tol) {
            stable_count++;
        } else {
            stable_count = 0;
        }

        prev_min = current_min;

        if (stable_count >= patience) {
            break;
        }

        if (batch_num >= 500) {
            break;
        }
    }

    return current_min;
}

// =============================================================================
// Exported function
// =============================================================================

//' Tukey (Halfspace) Depth
//'
//' Computes the Tukey halfspace depth of one or more query points with respect
//' to a reference distribution estimated from \code{data}, using an adaptive
//' random projection approximation.
//'
//' @param x Numeric matrix of query points (m x d), or a numeric vector
//'   of length d for a single query point.
//' @param data Numeric matrix of reference data (n x d).
//' @param tol Convergence tolerance. Default 0.01.
//' @param batch_size Number of random projections per batch. Default 100.
//' @param min_batches Minimum batches before checking convergence. Default 5.
//' @param patience Consecutive stable batches to declare convergence. Default 3.
//' @param seed Integer random seed for reproducibility. Default 42.
//'
//' @return Numeric vector of depth values in [0, 0.5], one per query point.
//'
//' @keywords internal
// [[Rcpp::export(name = ".tukey_depth_cpp")]]
Rcpp::NumericVector tukey_depth_cpp(
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
    if (n_data < d + 1)
        Rcpp::stop("data must have more rows than columns (n > d).");
    if (tol <= 0.0 || tol >= 1.0)
        Rcpp::stop("tol must be in (0, 1).");
    if (batch_size < 1)
        Rcpp::stop("batch_size must be >= 1.");
    if (patience < 1)
        Rcpp::stop("patience must be >= 1.");

    // memcpy for full matrix — contiguous in column-major storage
    // Data and xi are owned Eigen objects, not Maps — safe to pass to
    // parallel worker since they use standard heap, not R's allocator
    MatrixXd Data(n_data, d);
    std::memcpy(Data.data(), Data_map.data(), n_data * d * sizeof(double));

    Rcpp::NumericVector depths(m);

    for (int i = 0; i < m; i++) {
        // Element loop for row extraction — rows are strided in column-major
        VectorXd xi(d);
        for (int j = 0; j < d; j++)
            xi(j) = X_map(i, j);
        unsigned int point_seed = (unsigned int)seed + (unsigned int)(i * 10000);
        depths[i] = tukey_depth_single_adaptive(
            Data, xi,
            batch_size, min_batches, patience, tol,
            point_seed
        );
    }

    return depths;
}
