// Benchmark 3b: Realistic allocation (prevents optimization)
// Compile: g++ -O2 -std=c++17 -o allocation_realistic allocation_realistic.cpp
// Note: Using -O2 instead of -O3 to reduce aggressive optimization

#include <iostream>
#include <vector>
#include <chrono>
#include <random>

struct Point {
    int x, y;
    int data[10];  // Make it bigger to prevent optimizations
};

// Global to prevent optimizer from eliminating allocations
volatile long long g_sum = 0;

// Benchmark heap allocation (realistic: store pointers, use later)
long long benchmark_heap_realistic(size_t n) {
    std::vector<Point*> points;
    points.reserve(n);
    
    auto start = std::chrono::high_resolution_clock::now();
    
    // Allocate
    for (size_t i = 0; i < n; i++) {
        Point* p = new Point{};
        p->x = i;
        p->y = i;
        points.push_back(p);  // Store pointer (escapes)
    }
    
    auto alloc_end = std::chrono::high_resolution_clock::now();
    
    // Use the data (prevents dead code elimination)
    long long sum = 0;
    for (auto* p : points) {
        sum += p->x + p->y;
    }
    g_sum = sum;
    
    // Cleanup
    for (auto* p : points) {
        delete p;
    }
    
    return std::chrono::duration_cast<std::chrono::nanoseconds>(alloc_end - start).count();
}

// Benchmark stack allocation (realistic: values in vector)
long long benchmark_stack_realistic(size_t n) {
    std::vector<Point> points;
    points.reserve(n);
    
    auto start = std::chrono::high_resolution_clock::now();
    
    // Allocate (stored in vector's contiguous memory)
    for (size_t i = 0; i < n; i++) {
        Point p{};
        p.x = i;
        p.y = i;
        points.push_back(p);
    }
    
    auto alloc_end = std::chrono::high_resolution_clock::now();
    
    // Use the data (prevents dead code elimination)
    long long sum = 0;
    for (const auto& p : points) {
        sum += p.x + p.y;
    }
    g_sum = sum;
    
    return std::chrono::duration_cast<std::chrono::nanoseconds>(alloc_end - start).count();
}

int main() {
    const size_t n = 1000000;  // 1 million allocations
    
    std::cout << "Benchmarking realistic allocation patterns\n";
    std::cout << "Allocations: " << n << "\n";
    std::cout << "Object size: " << sizeof(Point) << " bytes\n\n";
    
    // Warm up
    benchmark_heap_realistic(1000);
    benchmark_stack_realistic(1000);
    
    // Benchmark heap allocation
    auto heap_time = benchmark_heap_realistic(n);
    auto heap_ms = heap_time / 1000000.0;
    auto heap_per_alloc = heap_time / n;
    
    std::cout << "Heap allocation (new + store pointer):\n";
    std::cout << "  Total time: " << heap_ms << " ms\n";
    std::cout << "  Time per allocation: " << heap_per_alloc << " ns\n\n";
    
    // Benchmark stack allocation
    auto stack_time = benchmark_stack_realistic(n);
    auto stack_ms = stack_time / 1000000.0;
    auto stack_per_alloc = stack_time / n;
    
    std::cout << "Stack allocation (push_back value):\n";
    std::cout << "  Total time: " << stack_ms << " ms\n";
    std::cout << "  Time per allocation: " << stack_per_alloc << " ns\n\n";
    
    // Calculate speedup
    double speedup = static_cast<double>(heap_time) / stack_time;
    std::cout << "Speedup: " << speedup << "x faster for stack-based storage\n";
    std::cout << "\nNote: This measures allocation + initialization + storage.\n";
    std::cout << "Heap requires malloc, stack requires vector growth (amortized).\n";
    
    return 0;
}
