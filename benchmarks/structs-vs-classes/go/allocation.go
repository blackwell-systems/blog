// Benchmark 3: Heap vs stack allocation (via escape analysis)
// Run: go run allocation.go
// To see escape analysis: go run -gcflags="-m" allocation.go

package main

import (
	"fmt"
	"time"
)

type Point struct {
	X, Y int
}

// Forces heap allocation (returns pointer)
func createHeap(i int) *Point {
	p := Point{X: i, Y: i}
	return &p  // Escapes to heap
}

// Stack allocation (value doesn't escape)
func createStack(i int) Point {
	p := Point{X: i, Y: i}
	return p  // Stays on stack
}

// Benchmark heap allocation
func benchmarkHeap(n int) time.Duration {
	start := time.Now()
	
	for i := 0; i < n; i++ {
		p := createHeap(i)
		
		// Use the pointer to prevent optimization
		if p.X < 0 {
			fmt.Println(p.X)
		}
	}
	
	return time.Since(start)
}

// Benchmark stack allocation
func benchmarkStack(n int) time.Duration {
	start := time.Now()
	
	for i := 0; i < n; i++ {
		p := createStack(i)
		
		// Use the value to prevent optimization
		if p.X < 0 {
			fmt.Println(p.X)
		}
	}
	
	return time.Since(start)
}

func main() {
	const n = 10000000  // 10 million allocations
	
	fmt.Println("Benchmarking Go heap vs stack allocation")
	fmt.Printf("Allocations: %d\n\n", n)
	
	// Warm up
	benchmarkHeap(1000)
	benchmarkStack(1000)
	
	// Benchmark heap allocation
	heapTime := benchmarkHeap(n)
	heapMicros := heapTime.Microseconds()
	heapPerAlloc := heapTime.Nanoseconds() / int64(n)
	
	fmt.Println("Heap allocation (escapes):")
	fmt.Printf("  Total time: %.2f ms\n", float64(heapMicros)/1000.0)
	fmt.Printf("  Time per allocation: %d ns\n\n", heapPerAlloc)
	
	// Benchmark stack allocation
	stackTime := benchmarkStack(n)
	stackMicros := stackTime.Microseconds()
	stackPerAlloc := stackTime.Nanoseconds() / int64(n)
	
	fmt.Println("Stack allocation (escape analysis):")
	fmt.Printf("  Total time: %.2f ms\n", float64(stackMicros)/1000.0)
	fmt.Printf("  Time per allocation: %d ns\n\n", stackPerAlloc)
	
	// Calculate speedup
	speedup := float64(heapTime) / float64(stackTime)
	fmt.Printf("Speedup: %.2fx faster for stack allocation\n", speedup)
}
