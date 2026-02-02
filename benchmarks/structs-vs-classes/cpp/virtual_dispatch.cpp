// Benchmark 2: Virtual dispatch vs static dispatch
// Compile: g++ -O3 -std=c++17 -o virtual_dispatch virtual_dispatch.cpp
// Run: ./virtual_dispatch

#include <iostream>
#include <vector>
#include <chrono>
#include <cmath>

// Virtual dispatch (polymorphic)
class Shape {
public:
    virtual ~Shape() = default;
    virtual double area() const = 0;
};

class Circle : public Shape {
    int radius;
public:
    explicit Circle(int r) : radius(r) {}
    double area() const override {
        return 3.14159 * radius * radius;
    }
};

// Static dispatch (concrete type)
struct ConcreteCircle {
    int radius;
    
    double area() const {
        return 3.14159 * radius * radius;
    }
};

// Benchmark virtual dispatch
long long benchmark_virtual(size_t n, int iterations) {
    std::vector<Shape*> shapes;
    shapes.reserve(n);
    
    for (size_t i = 0; i < n; i++) {
        shapes.push_back(new Circle(i));
    }
    
    auto start = std::chrono::high_resolution_clock::now();
    
    for (int iter = 0; iter < iterations; iter++) {
        double sum = 0;
        for (size_t i = 0; i < n; i++) {
            sum += shapes[i]->area();  // Virtual call
        }
        // Prevent optimization
        if (sum < 0) std::cout << sum;
    }
    
    auto end = std::chrono::high_resolution_clock::now();
    
    // Cleanup
    for (auto* s : shapes) {
        delete s;
    }
    
    return std::chrono::duration_cast<std::chrono::nanoseconds>(end - start).count();
}

// Benchmark static dispatch
long long benchmark_static(size_t n, int iterations) {
    std::vector<ConcreteCircle> circles;
    circles.reserve(n);
    
    for (size_t i = 0; i < n; i++) {
        circles.push_back({static_cast<int>(i)});
    }
    
    auto start = std::chrono::high_resolution_clock::now();
    
    for (int iter = 0; iter < iterations; iter++) {
        double sum = 0;
        for (size_t i = 0; i < n; i++) {
            sum += circles[i].area();  // Static call (can be inlined)
        }
        // Prevent optimization
        if (sum < 0) std::cout << sum;
    }
    
    auto end = std::chrono::high_resolution_clock::now();
    
    return std::chrono::duration_cast<std::chrono::nanoseconds>(end - start).count();
}

int main() {
    const size_t n = 10000000;  // 10 million calls
    const int iterations = 10;
    
    std::cout << "Benchmarking virtual dispatch vs static dispatch\n";
    std::cout << "Elements: " << n << "\n";
    std::cout << "Iterations: " << iterations << "\n";
    std::cout << "Total calls: " << n * iterations << "\n\n";
    
    // Warm up
    benchmark_virtual(1000, 10);
    benchmark_static(1000, 10);
    
    // Benchmark virtual dispatch
    auto virtual_time = benchmark_virtual(n, iterations);
    auto virtual_ms = virtual_time / 1000000.0;
    auto virtual_per_call = virtual_time / (n * iterations);
    
    std::cout << "Virtual dispatch (inheritance + vtable):\n";
    std::cout << "  Total time: " << virtual_ms << " ms\n";
    std::cout << "  Time per call: " << virtual_per_call << " ns\n\n";
    
    // Benchmark static dispatch
    auto static_time = benchmark_static(n, iterations);
    auto static_ms = static_time / 1000000.0;
    auto static_per_call = static_time / (n * iterations);
    
    std::cout << "Static dispatch (concrete type):\n";
    std::cout << "  Total time: " << static_ms << " ms\n";
    std::cout << "  Time per call: " << static_per_call << " ns\n\n";
    
    // Calculate speedup
    double speedup = static_cast<double>(virtual_time) / static_time;
    std::cout << "Speedup: " << speedup << "x faster for static dispatch\n";
    
    return 0;
}
