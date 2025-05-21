struct Vec3 {
    float x, y, z;
    __host__ __device__ Vec3() : x(0), y(0), z(0) {}
    __host__ __device__ Vec3(float x, float y, float z) : x(x), y(y), z(z) {}
    __host__ __device__ Vec3 operator+(const Vec3 &v) const {
        return Vec3(x + v.x, y + v.y, z + v.z);
    }
    __host__ __device__ Vec3 operator-(const Vec3 &v) const {
        return Vec3(x - v.x, y - v.y, z - v.z);
    }
    __host__ __device__ Vec3 operator*(float scalar) const {
        return Vec3(x * scalar, y * scalar, z * scalar);
    }
    __host__ __device__ float dot(const Vec3 &v) const {
        return x * v.x + y * v.y + z * v.z;
    }
};
__global__ void vec_add(Vec3 *a, Vec3 *b, Vec3 *c, int n) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    if (i < n) {
        c[i] = a[i] + b[i];
    }
}
int main() {
    const int n = 16;
    Vec3 a[n], b[n], c[n];
    Vec3 *d_a, *d_b, *d_c;
    for (int i = 0; i < n; ++i) {
        a[i] = Vec3(i, i*2, i*3);
        b[i] = Vec3(i*3, i*2, i);
    }
    cudaMalloc(&d_a, n * sizeof(Vec3));
    cudaMalloc(&d_b, n * sizeof(Vec3));
    cudaMalloc(&d_c, n * sizeof(Vec3));
    cudaMemcpy(d_a, a, n * sizeof(Vec3), cudaMemcpyHostToDevice);
    cudaMemcpy(d_b, b, n * sizeof(Vec3), cudaMemcpyHostToDevice);
    vec_add<<<1, n>>>(d_a, d_b, d_c, n);
    cudaMemcpy(c, d_c, n * sizeof(Vec3), cudaMemcpyDeviceToHost);
    for (int i = 0; i < n; ++i) {
        printf("Vec3(%f, %f, %f)\n", c[i].x, c[i].y, c[i].z);
    }
    cudaFree(d_a);
    cudaFree(d_b);
    cudaFree(d_c);
    return 0;
}
