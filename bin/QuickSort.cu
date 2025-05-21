#include <cstdio>
__global__ void bubble_sort(int *arr, int n) {
    int i, j, temp;
    for (i = 0; i < n-1; i++) {
        for (j = 0; j < n-i-1; j++) {
            if (arr[j] > arr[j+1]) {
                temp = arr[j];
                arr[j] = arr[j+1];
                arr[j+1] = temp;
            }
        }
    }
}
int main() {
    const int n = 10;
    int arr[n] = {10,9,8,7,6,5,4,3,2,1};
    int *d_arr;
    cudaMalloc((void**)&d_arr, n * sizeof(int));
    cudaMemcpy(d_arr, arr, n * sizeof(int), cudaMemcpyHostToDevice);
    bubble_sort<<<1,1>>>(d_arr, n);
    cudaMemcpy(arr, d_arr, n * sizeof(int), cudaMemcpyDeviceToHost);
    for (int i = 0; i < n; i++) {
        printf("%d ", arr[i]);
    }
    printf("\n");
    cudaFree(d_arr);
    return 0;
}
#include <iostream>
#include <vector>
#include <algorithm>
void quicksort(std::vector<int>& a,int low,int high){
    if(low<high){
        int pivot=a[(low+high)/2];
        int i=low;
        int j=high;
        while(i<=j){
            while(a[i]<pivot) i++;
            while(a[j]>pivot) j--;
            if(i<=j){
                std::swap(a[i],a[j]);
                i++;
                j--;
            }
        }
        if(low<j) quicksort(a,low,j);
        if(i<high) quicksort(a,i,high);
    }
}
int main(){
    std::vector<int> data{33,2,52,106,73,10,5,17,49,69,100,39,29};
    quicksort(data,0,data.size()-1);
    for(size_t i=0;i<data.size();++i){
        std::cout<<data[i];
        if(i+1<data.size()) std::cout<<" ";
    }
    std::cout<<"\n";
    return 0;
}