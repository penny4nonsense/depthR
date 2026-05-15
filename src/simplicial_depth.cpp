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
#include <numeric>
#include <random>
#include <vector>

using Eigen::MatrixXd;
using Eigen::VectorXd;
using Eigen::ColPivHouseholderQR;

typedef Eigen::Map<Eigen::MatrixXd> MapMatrixXd;

// =============================================================================
// Internal helpers
// =============================================================================

// Sample d+1 distinct indices from [0, n) without replacement using
// partial Fisher-Yates shuffle. Each thread passes its own rng.
inline void sample_simplex(int n, int d,
                            std::vector<int>& indices,
                            std::vector<int>& pool,
                            std::mt19937& rng) {
    // Reset pool to 0..n-1 — only need to reset the first d+1 slots
    // since we restore as we go
    int k = d + 1;
    for (int i = 0; i < k; i++) {
        std::uniform_int_distribution<int> dist(i, n - 1);
        int j = dist(rng);
        std::swap(pool[i], pool[j]);
        indices[i] = pool[i];
    }
}

// Check whether point x lies inside the simplex defined by vertices
// stored as rows of 'simplex' (a (d+1) x d matrix).
// Returns true if x is inside, false otherwise or if simplex is degenerate.
inline bool point_in_simplex(const MatrixXd& simplex,
                              const VectorXd& x,
                              int d) {
    // Form the d x d matrix A = [v_1 - v_0, ..., v_d - v_0]
    // and solve A * lambda = x - v_0
    VectorXd v0(d);
    for (int j = 0; j < d; j++)
        v0(j) = simplex(0, j);

    MatrixXd A(d, d);
    for (int col = 0; col < d; col++)
        for (int row = 0; row < d; row++)
            A(row, col) = simplex(col + 1, row) - v0(row);

    VectorXd rhs(d);
    for (int j = 0; j < d; j++)
        rhs(j) = x(j) - v0(j);

    // Use column-pivoting QR — stable for nearly singular matrices
    ColPivHouseholderQR<MatrixXd> qr(A);

    // Check for degenerate simplex — zero volume
    if (qr.rank() < d) {
        return false;
    }

    VectorXd lambda = qr.solve(rhs);

    // x is inside if all lambda >= 0 and sum(lambda) <= 1
    double sum = 0.0;
    for (int i = 0; i < d; i++) {
        if (lambda(i) < 0.0) return false;
        sum += lambda(i);
    }
    return sum <= 1.0;
}

// =============================================================================
// RcppParallel Worker
// =============================================================================

struct SimplicialWorker : public RcppParallel::Worker {

    const MatrixXd& data;   // n x d — owned MatrixXd, safe for parallel
    const VectorXd& x;      // query point, length d
    int n;
    int d;
    int batch_size;
    unsigned int base_seed;

    // Per-thread accumulators — each thread writes to its own slot
    std::vector<int> local_count;   // simplices containing x
    std::vector<int> local_total;   // simplices attempted (non-degenerate)

    SimplicialWorker(const MatrixXd& data_,
                     const VectorXd& x_,
                     unsigned int base_seed_,
                     int batch_size_)
        : data(data_),
          x(x_),
          n(data_.rows()),
          d(data_.cols()),
          batch_size(batch_size_),
          base_seed(base_seed_),
          local_count(batch_size_, 0),
          local_total(batch_size_, 0)
    {}

    void operator()(std::size_t begin, std::size_t end) {
        std::mt19937 rng(base_seed + (unsigned int)begin);

        // Each thread gets its own pool for Fisher-Yates
        std::vector<int> pool(n);
        std::iota(pool.begin(), pool.end(), 0);

        std::vector<int> indices(d + 1);

        // Simplex vertex matrix — (d+1) x d
        MatrixXd simplex(d + 1, d);

        int count = 0;
        int total = 0;

        for (std::size_t idx = begin; idx < end; idx++) {
            // Sample d+1 distinct points from data
            sample_simplex(n, d, indices, pool, rng);

            // Fill simplex matrix — rows are vertices
            for (int v = 0; v <= d; v++)
                for (int j = 0; j < d; j++)
                    simplex(v, j) = data(indices[v], j);

            // Check containment
            bool inside = point_in_simplex(simplex, x, d);
            if (inside) count++;
            total++;
        }

        // Write results — each thread owns unique index range
        for (std::size_t idx = begin; idx < end; idx++) {
            local_count[idx] = count;
            local_total[idx] = total;
        }
    }
};

// =============================================================================
// Adaptive stopping rule
//
// For simplicial depth we're estimating a mean (Bernoulli proportion),
// so we use the proper standard error:
//   se = sqrt(p_hat * (1 - p_hat) / M)
// Stop when se / max(p_hat, epsilon) < tol.
// This is much cleaner than the patience/stability approach used for Tukey.
// =============================================================================

double simplicial_depth_single_adaptive(const MatrixXd& data,
                                         const VectorXd& x,
                                         int batch_size,
                                         int min_batches,
                                         int max_batches,
                                         double tol,
                                         unsigned int seed) {
    int total_count = 0;
    int total_tried = 0;
    int batch_num   = 0;

    while (true) {
        unsigned int batch_seed = seed + (unsigned int)(batch_num * batch_size);

        SimplicialWorker worker(data, x, batch_seed, batch_size);
        RcppParallel::parallelFor(0, batch_size, worker);

        // Reduce across threads
        for (int i = 0; i < batch_size; i++) {
            total_count += worker.local_count[i];
            total_tried += worker.local_total[i];
        }
        batch_num++;

        // Don't check stopping rule until minimum batches done
        if (batch_num < min_batches) continue;

        // Bernoulli standard error stopping rule
        if (total_tried == 0) break;
        double p_hat = (double)total_count / (double)total_tried;
        double se    = std::sqrt(p_hat * (1.0 - p_hat) / (double)total_tried);
        double eps   = 1e-6;
        double rel_se = se / std::max(p_hat, eps);

        if (rel_se < tol) break;

        // Safety valve — respect max_batches
        if (batch_num >= max_batches) break;
    }

    if (total_tried == 0) return 0.0;
    return (double)total_count / (double)total_tried;
}

// =============================================================================
// Exported function
// =============================================================================

//' Liu Simplicial Depth
//'
//' Computes the simplicial depth of one or more query points with respect
//' to a reference distribution estimated from \code{data}, using an adaptive
//' Monte Carlo approximation.
//'
//' @details
//' Simplicial depth of a point x with respect to distribution F is defined as
//' the probability that a random simplex formed by d+1 independent draws from
//' F contains x:
//' \deqn{SD(x, F) = P(x \in S[X_1, \ldots, X_{d+1}])}
//' where \eqn{S[X_1, \ldots, X_{d+1}]} denotes the closed simplex with
//' vertices \eqn{X_1, \ldots, X_{d+1}}.
//'
//' This is estimated by sampling random simplices from the empirical
//' distribution and checking containment via barycentric coordinates.
//' The adaptive stopping rule uses the Bernoulli standard error to determine
//' when the estimate has converged.
//'
//' @param x Numeric matrix of query points (m x d), or a numeric vector
//'   of length d for a single query point.
//' @param data Numeric matrix of reference data (n x d). Must have at least
//'   d+1 rows.
//' @param tol Relative standard error tolerance for the stopping rule.
//'   Default 0.05 (5\%).
//' @param batch_size Number of random simplices per batch. Default 200.
//' @param min_batches Minimum number of batches before checking convergence.
//'   Default 3.
//' @param max_batches Maximum number of batches regardless of convergence.
//'   Acts as a hard cap on computation time. Default 20.
//' @param seed Integer random seed for reproducibility. Default 42.
//'
//' @return Numeric vector of depth values in [0, 1], one per query point.
//'
//' @references
//' Liu, R. Y. (1990). On a notion of data depth based on random simplices.
//' \emph{Annals of Statistics}, 18(1), 405--414.
//'
//' @keywords internal
// [[Rcpp::export(name = ".simplicial_depth_cpp")]]
Rcpp::NumericVector simplicial_depth_cpp(
    Rcpp::NumericMatrix x,
    Rcpp::NumericMatrix data,
    double tol        = 0.05,
    int batch_size    = 200,
    int min_batches   = 3,
    int max_batches   = 20,
    int seed          = 42) {

    MapMatrixXd X_map    = Rcpp::as<MapMatrixXd>(x);
    MapMatrixXd Data_map = Rcpp::as<MapMatrixXd>(data);

    int m      = X_map.rows();
    int d      = X_map.cols();
    int n_data = Data_map.rows();

    if (Data_map.cols() != d)
        Rcpp::stop("x and data must have the same number of columns.");
    if (n_data < d + 1)
        Rcpp::stop("data must have at least d+1 rows to form a simplex.");
    if (tol <= 0.0 || tol >= 1.0)
        Rcpp::stop("tol must be in (0, 1).");
    if (batch_size < 1)
        Rcpp::stop("batch_size must be >= 1.");
    if (max_batches < min_batches)
        Rcpp::stop("max_batches must be >= min_batches.");

    // memcpy for full matrix — contiguous in column-major storage
    // Owned MatrixXd is safe to pass to parallel worker
    MatrixXd Data(n_data, d);
    std::memcpy(Data.data(), Data_map.data(), n_data * d * sizeof(double));

    Rcpp::NumericVector depths(m);

    for (int i = 0; i < m; i++) {
        // Element loop for row extraction — rows are strided in column-major
        VectorXd xi(d);
        for (int j = 0; j < d; j++)
            xi(j) = X_map(i, j);

        unsigned int point_seed = (unsigned int)seed + (unsigned int)(i * 10000);
        depths[i] = simplicial_depth_single_adaptive(
            Data, xi,
            batch_size, min_batches, max_batches, tol,
            point_seed
        );
    }

    return depths;
}
