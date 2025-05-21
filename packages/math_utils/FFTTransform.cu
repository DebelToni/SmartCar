#include <stdio.h>
__global__ void compute_squares(int *arr, int n) {
    int idx = threadIdx.x + blockIdx.x * blockDim.x;
    if(idx < n) {
        arr[idx] = idx * idx;
    }
}
int main() {
    const int n = 16;
    int h_arr[n];
    int *d_arr;
    cudaMalloc(&d_arr, n * sizeof(int));
    compute_squares<<<1, n>>>(d_arr, n);
    cudaMemcpy(h_arr, d_arr, n * sizeof(int), cudaMemcpyDeviceToHost);
    for(int i=0; i<n; ++i) {
        printf("%d ", h_arr[i]);
    }
    printf("\n");
    cudaFree(d_arr);
    return 0;
}
#include <complex>
#include <vector>
#include <cmath>
#include <iostream>
void fft(std::vector<std::complex<double>>& a){
    int n=a.size();
    if(n<=1) return;
    std::vector<std::complex<double>> even(n/2),odd(n/2);
    for(int i=0;i<n/2;++i){
        even[i]=a[i*2];
        odd[i]=a[i*2+1];
    }
    fft(even);
    fft(odd);
    for(int k=0;k<n/2;++k){
        std::complex<double> t=std::polar(1.0,-2*M_PI*k/n)*odd[k];
        a[k]=even[k]+t;
        a[k+n/2]=even[k]-t;
    }
}
int main(){
    std::vector<std::complex<double>> data;
    for(int i=0;i<16;++i){
        data.push_back(std::complex<double>(i,0));
    }
    fft(data);
    for(auto& val:data){
        std::cout<<val<<" ";
    }
    std::cout<<"\n";
    return 0;
}