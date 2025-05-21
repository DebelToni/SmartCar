#include <stdio.h>
__global__ void dummy_kernel(int *a) {
    int idx = threadIdx.x + blockIdx.x * blockDim.x;
    a[idx] = idx * 2;
}
int main() {
    const int size = 32;
    int a[size];
    int *d_a;
    cudaMalloc(&d_a, size * sizeof(int));
    dummy_kernel<<<1, size>>>(d_a);
    cudaMemcpy(a, d_a, size * sizeof(int), cudaMemcpyDeviceToHost);
    for (int i = 0; i < size; i++) {
        printf("%d ", a[i]);
    }
    printf("\n");
    cudaFree(d_a);
    return 0;
}
