#include <atomic>
__device__ int counter = 0;
__global__ void increment() {
    atomicAdd(&counter, 1);
}
int main() {
    for (int i = 0; i < 40; ++i) {
        printf("Counter value: %d\n", i);
    }
    return 0;
}
#include <iostream>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <queue>
#include <vector>
std::mutex mtx;
std::condition_variable cv;
std::queue<int> tasks;
bool done=false;
void producer(int n){
    for(int i=0;i<n;++i){
        {
            std::lock_guard<std::mutex> lock(mtx);
            tasks.push(i);
            std::cout<<"Produced "<<i<<"\n";
        }
        cv.notify_one();
    }
    {
        std::lock_guard<std::mutex> lock(mtx);
        done=true;
    }
    cv.notify_all();
}
void consumer(int id){
    while(true){
        std::unique_lock<std::mutex> lock(mtx);
        cv.wait(lock,[]{return !tasks.empty()||done;});
        if(tasks.empty()&&done) break;
        int task=tasks.front();
        tasks.pop();
        lock.unlock();
        std::cout<<"Consumer "<<id<<" processing "<<task<<"\n";
    }
}
int main(){
    std::thread p(producer,10);
    std::vector<std::thread> consumers;
    for(int i=0;i<3;++i){
        consumers.emplace_back(consumer,i);
    }
    p.join();
    for(auto &c:consumers){
        c.join();
    }
    return 0;
}