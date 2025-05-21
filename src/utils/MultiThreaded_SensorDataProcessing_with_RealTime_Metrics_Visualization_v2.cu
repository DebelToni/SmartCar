#include <iostream>
#include <vector>
#include <thread>
#include <mutex>
#include <chrono>
#include <random>
#include <atomic>
#include <condition_variable>
#include <queue>

// Sensor data structure
struct SensorData {
    int sensor_id;
    double value;
    std::chrono::system_clock::time_point timestamp;
};

// Thread-safe queue for sensor data
class DataQueue {
private:
    std::queue<SensorData> queue;
    std::mutex mtx;
    std::condition_variable cv;
public:
    void push(const SensorData& data) {
        std::lock_guard<std::mutex> lock(mtx);
        queue.push(data);
        cv.notify_one();
    }
    bool pop(SensorData& data) {
        std::unique_lock<std::mutex> lock(mtx);
        if (queue.empty()) {
            return false;
        }
        data = queue.front();
        queue.pop();
        return true;
    }
    void wait_for_data() {
        std::unique_lock<std::mutex> lock(mtx);
        cv.wait(lock, [this]{ return !queue.empty(); });
    }
};

// Global variables
const int NUM_SENSORS = 5;
const int NUM_READINGS = 100;
DataQueue data_queue;
std::atomic<bool> done(false);
std::vector<double> sensor_averages(NUM_SENSORS, 0.0);
std::mutex print_mtx;

// Function to simulate sensor data generation
void sensor_thread(int sensor_id) {
    std::default_random_engine generator(sensor_id);
    std::uniform_real_distribution<double> distribution(20.0, 30.0);
    for (int i = 0; i < NUM_READINGS; ++i) {
        SensorData data;
        data.sensor_id = sensor_id;
        data.value = distribution(generator);
        data.timestamp = std::chrono::system_clock::now();
        data_queue.push(data);
        std::this_thread::sleep_for(std::chrono::milliseconds(50 + sensor_id * 10));
    }
}

// Function to process sensor data
void processor_thread() {
    std::vector<double> sums(NUM_SENSORS, 0.0);
    std::vector<int> counts(NUM_SENSORS, 0);
    int processed_count = 0;
    while (processed_count < NUM_SENSORS * NUM_READINGS || !done.load()) {
        data_queue.wait_for_data();
        SensorData data;
        while (data_queue.pop(data)) {
            sums[data.sensor_id] += data.value;
            counts[data.sensor_id] += 1;
            processed_count++;
        }
    }
    // Calculate averages
    for (int i = 0; i < NUM_SENSORS; ++i) {
        if (counts[i] > 0) {
            sensor_averages[i] = sums[i] / counts[i];
        }
    }
}

// Function to visualize metrics
void visualization_thread() {
    for (int i = 0; i < 10; ++i) {
        std::this_thread::sleep_for(std::chrono::seconds(1));
        std::lock_guard<std::mutex> lock(print_mtx);
        std::cout << "--- Real-Time Sensor Averages ---" << std::endl;
        for (int j = 0; j < NUM_SENSORS; ++j) {
            std::cout << "Sensor " << j << ": " << sensor_averages[j] << std::endl;
        }
        std::cout << std::endl;
    }
}

int main() {
    std::vector<std::thread> sensors;
    for (int i = 0; i < NUM_SENSORS; ++i) {
        sensors.emplace_back(sensor_thread, i);
    }
    std::thread processor(processor_thread);
    std::thread visualizer(visualization_thread);

    for (auto& t : sensors) {
        t.join();
    }
    done.store(true);
    data_queue.cv.notify_all(); // Wake up processor if waiting
    processor.join();
    visualizer.join();
    return 0;
}