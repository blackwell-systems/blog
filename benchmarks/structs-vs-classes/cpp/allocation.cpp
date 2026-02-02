// Benchmark 3: Heap allocation vs stack allocation
// Compile: g++ -O3 -std=c++17 -o allocation allocation.cpp
// Run: ./allocation

#include <iostream>
#include <chrono>

struct Point {
    int x, y;
};

// Benchmark heap allocation
long long benchmark_heap(size_t n) {
    auto start = std::chrono::high_resolution_clock::now();
    
    for (size_t i = 0; i < n; i++) {
        Point* p = new Point{static_cast<int>(i), static_cast<int>(i)};
        
        // Use the pointer to prevent optimization
        if (p->x < 0) std::cout << p->x;
        
        delete p;
    }
    
    auto end = std::chrono::high_resolution_clock::now();
    
    return std::chrono::duration_cast<std::chrono::nanoseconds>(end - start).count();
}

// Benchmark stack allocation
long long benchmark_stack(size_t n) {
    auto start = std::chrono::high_resolution_clock::now();
    
    for (size_t i = 0; i < n; i++) {
        Point p{static_cast<int>(i), static_cast<int>(i)};
        
        // Use the value to prevent optimization
        if (p.x < 0) std::cout << p.x;
    }
    
    auto end = std::chrono::high_resolution_clock::now();
    
    return std::chrono::duration_cast<std::chrono::nanoseconds>(end - start).count();
}

int main() {
    const size_t n = 10000000;  // 10 million allocations
    
    std::cout << "Benchmarking heap vs stack allocation\n";
    std::cout << "Allocations: " << n << "\n\n";
    
    // Warm up
    benchmark_heap(1000);
    benchmark_stack(1000);
    
    // Benchmark heap allocation
    auto heap_time = benchmark_heap(n);
    auto heap_ms = heap_time / 1000000.0;
    auto heap_per_alloc = heap_time / n;
    
    std::cout << "Heap allocation (new/delete):\n";
    std::cout << "  Total time: " << heap_ms << " ms\n";
    std::cout << "  Time per allocation: " << heap_per_alloc << " ns\n\n";
    
    // Benchmark stack allocation
    auto stack_time = benchmark_stack(n);
    auto stack_ms = stack_time / 1000000.0;
    auto stack_per_alloc = stack_time / n;
    
    std::cout << "Stack allocation (automatic storage):\n";
    std::cout << "  Total time: " << stack_ms << " ms\n";
    std::cout << "  Time per allocation: " << stack_per_alloc << " ns\n\n";
    
    // Calculate speedup
    double speedup = static_cast<double>(heap_time) / stack_time;
    std::cout << "Speedup: " << speedup << "x faster for stack allocation\n";
    
    return 0;
}
