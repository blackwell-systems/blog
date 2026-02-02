// Benchmark 3b: Realistic allocation (prevents optimization)
// Run: go run allocation_realistic.go
// Compare with: go run -gcflags="-m" allocation_realistic.go 2>&1 | grep escape

package main

import (
	"fmt"
	"time"
	"unsafe"
)

type Point struct {
	X, Y int
	Data [10]int  // Make it bigger to prevent optimizations
}

// Global to prevent optimizer from eliminating allocations
var gSum int64

// Benchmark heap allocation (store pointers in slice)
func benchmarkHeapRealistic(n int) time.Duration {
	points := make([]*Point, 0, n)
	
	start := time.Now()
	
	// Allocate (escapes to heap)
	for i := 0; i < n; i++ {
		p := &Point{}
		p.X = i
		p.Y = i
		points = append(points, p)  // Store pointer (forces escape)
	}
	
	allocEnd := time.Now()
	
	// Use the data (prevents dead code elimination)
	sum := int64(0)
	for _, p := range points {
		sum += int64(p.X + p.Y)
	}
	gSum = sum
	
	return allocEnd.Sub(start)
}

// Benchmark stack allocation (values in slice)
func benchmarkStackRealistic(n int) time.Duration {
	points := make([]Point, 0, n)
	
	start := time.Now()
	
	// Allocate (stays in slice's contiguous memory)
	for i := 0; i < n; i++ {
		p := Point{}
		p.X = i
		p.Y = i
		points = append(points, p)  // Store value
	}
	
	allocEnd := time.Now()
	
	// Use the data (prevents dead code elimination)
	sum := int64(0)
	for _, p := range points {
		sum += int64(p.X + p.Y)
	}
	gSum = sum
	
	return allocEnd.Sub(start)
}

func main() {
	const n = 1000000  // 1 million allocations
	
	fmt.Println("Benchmarking Go realistic allocation patterns")
	fmt.Printf("Allocations: %d\n", n)
	fmt.Printf("Object size: %d bytes\n\n", int(unsafe.Sizeof(Point{})))
	
	// Warm up
	benchmarkHeapRealistic(1000)
	benchmarkStackRealistic(1000)
	
	// Benchmark heap allocation
	heapTime := benchmarkHeapRealistic(n)
	heapMicros := heapTime.Microseconds()
	heapPerAlloc := heapTime.Nanoseconds() / int64(n)
	
	fmt.Println("Heap allocation (pointer slice):")
	fmt.Printf("  Total time: %.2f ms\n", float64(heapMicros)/1000.0)
	fmt.Printf("  Time per allocation: %d ns\n\n", heapPerAlloc)
	
	// Benchmark stack allocation
	stackTime := benchmarkStackRealistic(n)
	stackMicros := stackTime.Microseconds()
	stackPerAlloc := stackTime.Nanoseconds() / int64(n)
	
	fmt.Println("Value slice (contiguous storage):")
	fmt.Printf("  Total time: %.2f ms\n", float64(stackMicros)/1000.0)
	fmt.Printf("  Time per allocation: %d ns\n\n", stackPerAlloc)
	
	// Calculate speedup
	speedup := float64(heapTime) / float64(stackTime)
	fmt.Printf("Speedup: %.2fx faster for value storage\n", speedup)
	fmt.Println("\nNote: This measures allocation + initialization + append.")
	fmt.Println("Heap requires malloc per object, value slice grows contiguously.")
}
