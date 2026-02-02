// Benchmark 1: Pointer chasing vs contiguous memory
// Compile: g++ -O3 -std=c++17 -o pointer_chasing pointer_chasing.cpp
// Run: ./pointer_chasing

#include <iostream>
#include <vector>
#include <chrono>
#include <numeric>

struct Point {
    int x, y;
};

// Measure pointer array (scattered memory)
long long benchmark_pointer_array(size_t n, int iterations) {
    std::vector<Point*> points;
    points.reserve(n);
    
    // Allocate scattered on heap
    for (size_t i = 0; i < n; i++) {
        points.push_back(new Point{static_cast<int>(i), static_cast<int>(i)});
    }
    
    auto start = std::chrono::high_resolution_clock::now();
    
    for (int iter = 0; iter < iterations; iter++) {
        long long sum = 0;
        for (size_t i = 0; i < n; i++) {
            sum += points[i]->x + points[i]->y;
        }
        // Prevent optimization
        if (sum < 0) std::cout << sum;
    }
    
    auto end = std::chrono::high_resolution_clock::now();
    
    // Cleanup
    for (auto* p : points) {
        delete p;
    }
    
    return std::chrono::duration_cast<std::chrono::nanoseconds>(end - start).count();
}

// Measure value array (contiguous memory)
long long benchmark_value_array(size_t n, int iterations) {
    std::vector<Point> points;
    points.reserve(n);
    
    // Stored inline in vector
    for (size_t i = 0; i < n; i++) {
        points.push_back({static_cast<int>(i), static_cast<int>(i)});
    }
    
    auto start = std::chrono::high_resolution_clock::now();
    
    for (int iter = 0; iter < iterations; iter++) {
        long long sum = 0;
        for (size_t i = 0; i < n; i++) {
            sum += points[i].x + points[i].y;
        }
        // Prevent optimization
        if (sum < 0) std::cout << sum;
    }
    
    auto end = std::chrono::high_resolution_clock::now();
    
    return std::chrono::duration_cast<std::chrono::nanoseconds>(end - start).count();
}

int main() {
    const size_t n = 1000000;  // 1 million points
    const int iterations = 100;
    
    std::cout << "Benchmarking pointer chasing vs contiguous memory\n";
    std::cout << "Elements: " << n << "\n";
    std::cout << "Iterations: " << iterations << "\n\n";
    
    // Warm up
    benchmark_pointer_array(1000, 10);
    benchmark_value_array(1000, 10);
    
    // Benchmark pointer array
    auto pointer_time = benchmark_pointer_array(n, iterations);
    auto pointer_ms = pointer_time / 1000000.0;
    auto pointer_per_element = pointer_time / (n * iterations);
    
    std::cout << "Pointer array (scattered heap):\n";
    std::cout << "  Total time: " << pointer_ms << " ms\n";
    std::cout << "  Time per element: " << pointer_per_element << " ns\n\n";
    
    // Benchmark value array
    auto value_time = benchmark_value_array(n, iterations);
    auto value_ms = value_time / 1000000.0;
    auto value_per_element = value_time / (n * iterations);
    
    std::cout << "Value array (contiguous memory):\n";
    std::cout << "  Total time: " << value_ms << " ms\n";
    std::cout << "  Time per element: " << value_per_element << " ns\n\n";
    
    // Calculate speedup
    double speedup = static_cast<double>(pointer_time) / value_time;
    std::cout << "Speedup: " << speedup << "x faster for contiguous memory\n";
    
    return 0;
}
