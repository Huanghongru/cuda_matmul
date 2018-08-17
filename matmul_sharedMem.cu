#include "utils.cpp"

const int TILE_SIZE = 16;

template <typename T>
__global__ void matmul_share(T* a, T* b, T* c, int M, int K, int N) {
    /* A naive implementation of matrix multiplication.
     * a: MxK
     * b: KxN
     * c: MxN
     * 
     * Average Time: 1000x1000x1000, 
     * Average Time: 1024x1024x1024, 35.035ms
     */
    int x = threadIdx.x + blockIdx.x*blockDim.x;
    int y = threadIdx.y + blockIdx.y*blockDim.y;

    // One element of c is computed block-wise.
    // We can't set this element to 0 at each block,
    // so we need a temp variable.
    T cvalue = 0;

    // To simplify, we just consider the case that matrix
    // sizes are multiple of block size, which means no
    // outside loop is required.

    // Construct submatrix in shared memory for threads in
    // each block. Each thread loads one element of submatrix.
    const int asubRow = TILE_SIZE;
    const int asubCol = TILE_SIZE;
    const int bsubRow = TILE_SIZE;
    const int bsubCol = TILE_SIZE;

    __shared__ T asub[asubRow][asubCol];
    __shared__ T bsub[bsubRow][bsubCol];
    // Synchroonize to make sure the submatrices are loaded
    // before starting the computation.

    // For a single value of c, must iterate all the tile.
    for (int i = 0; i < gridDim.x; ++i) {		
        asub[threadIdx.x][threadIdx.y] = a[x*M+threadIdx.y+i*blockDim.y];
        bsub[threadIdx.x][threadIdx.y] = b[(threadIdx.x+i*blockDim.x)*M+y];
        __syncthreads();

	for (int k = 0; k < blockDim.x; ++k) {
	    cvalue += asub[threadIdx.x][k]*bsub[k][threadIdx.y];
	}
	__syncthreads();
    }
    c[x*M+y] += cvalue;
}

int main(int argc, char *argv[]) {
    int M = std::atoi(argv[1]), K = std::atoi(argv[2]), N = std::atoi(argv[3]);
    dim3 threadsPerBlock(TILE_SIZE, TILE_SIZE);
    dim3 blocksPerGrid;
    blocksPerGrid.x = M / threadsPerBlock.x;
    blocksPerGrid.y = N / threadsPerBlock.y;
    blocksPerGrid.z = 1;

    double* a = utils::random_matrix_gpu<double>(M, K, utils::C_ORDER);
    double* b = utils::random_matrix_gpu<double>(K, N, utils::C_ORDER);
    double* c = new double[M*N];
    double *dev_a, *dev_b, *dev_c;

    cudaMalloc((void**)&dev_a, M*K*sizeof(double));
    cudaMalloc((void**)&dev_b, K*N*sizeof(double));
    cudaMalloc((void**)&dev_c, M*N*sizeof(double));

    cudaMemcpy(dev_a, a, M*K*sizeof(double), cudaMemcpyHostToDevice);
    cudaMemcpy(dev_b, b, K*N*sizeof(double), cudaMemcpyHostToDevice);
    matmul_share<double><<<blocksPerGrid, threadsPerBlock>>>(dev_a, dev_b, dev_c, M, K, N);
    cudaMemcpy(c, dev_c, M*N*sizeof(double), cudaMemcpyDeviceToHost);

    std::cout << (utils::check_mul<double>(a, b, c, M, K, N, utils::C_ORDER) 
		    ? "Correct!!" : "Wrong Answer!") << std::endl;
#ifdef DEBUG
    std::cout << "Matrix A:" << std::endl;
    utils::print_mat_gpu(a, M, K, utils::C_ORDER);
    std::cout << "Matrix B:" << std::endl;
    utils::print_mat_gpu(b, K, N, utils::C_ORDER);
    std::cout << "Matrix C:" << std::endl;
    utils::print_mat_gpu(c, M, N, utils::C_ORDER);
#endif
    return 0;
}



