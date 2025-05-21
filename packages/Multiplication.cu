#include <iostream>
__global__ void multiply(int *a, int *b, int *c, int n) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < n) {
        c[idx] = a[idx] * b[idx];
    }
}
int main() {
    const int n = 32;
    int a[n], b[n], c[n];
    int *d_a, *d_b, *d_c;
    for (int i = 0; i < n; ++i) {
        a[i] = i+1;
        b[i] = (i+1) * 2;
    }
    cudaMalloc(&d_a, n * sizeof(int));
    cudaMalloc(&d_b, n * sizeof(int));
    cudaMalloc(&d_c, n * sizeof(int));
    cudaMemcpy(d_a, a, n * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_b, b, n * sizeof(int), cudaMemcpyHostToDevice);
    multiply<<<1, n>>>(d_a, d_b, d_c, n);
    cudaMemcpy(c, d_c, n * sizeof(int), cudaMemcpyDeviceToHost);
    for (int i = 0; i < n; ++i) {
        std::cout << a[i] << " * " << b[i] << " = " << c[i] << std::endl;
    }
    cudaFree(d_a);
    cudaFree(d_b);
    cudaFree(d_c);
    return 0;
}
