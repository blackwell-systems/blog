// Benchmark 1: Go value semantics (contiguous memory)
// Run: go run pointer_chasing.go

package main

import (
	"fmt"
	"time"
)

type Point struct {
	X, Y int
}

// Measure value array (contiguous memory)
func benchmarkValueArray(n int, iterations int) time.Duration {
	points := make([]Point, n)
	
	// Initialize
	for i := 0; i < n; i++ {
		points[i] = Point{X: i, Y: i}
	}
	
	start := time.Now()
	
	for iter := 0; iter < iterations; iter++ {
		sum := 0
		for i := 0; i < n; i++ {
			sum += points[i].X + points[i].Y
		}
		// Prevent optimization
		if sum < 0 {
			fmt.Println(sum)
		}
	}
	
	return time.Since(start)
}

// Measure pointer array (to simulate scattered memory)
func benchmarkPointerArray(n int, iterations int) time.Duration {
	points := make([]*Point, n)
	
	// Allocate on heap (scattered)
	for i := 0; i < n; i++ {
		points[i] = &Point{X: i, Y: i}
	}
	
	start := time.Now()
	
	for iter := 0; iter < iterations; iter++ {
		sum := 0
		for i := 0; i < n; i++ {
			sum += points[i].X + points[i].Y
		}
		// Prevent optimization
		if sum < 0 {
			fmt.Println(sum)
		}
	}
	
	return time.Since(start)
}

func main() {
	const n = 1000000  // 1 million points
	const iterations = 100
	
	fmt.Println("Benchmarking Go value semantics")
	fmt.Printf("Elements: %d\n", n)
	fmt.Printf("Iterations: %d\n\n", iterations)
	
	// Warm up
	benchmarkValueArray(1000, 10)
	benchmarkPointerArray(1000, 10)
	
	// Benchmark value array
	valueTime := benchmarkValueArray(n, iterations)
	valueMicros := valueTime.Microseconds()
	valuePerElement := valueTime.Nanoseconds() / int64(n*iterations)
	
	fmt.Println("Value array (contiguous memory):")
	fmt.Printf("  Total time: %.2f ms\n", float64(valueMicros)/1000.0)
	fmt.Printf("  Time per element: %d ns\n\n", valuePerElement)
	
	// Benchmark pointer array
	pointerTime := benchmarkPointerArray(n, iterations)
	pointerMicros := pointerTime.Microseconds()
	pointerPerElement := pointerTime.Nanoseconds() / int64(n*iterations)
	
	fmt.Println("Pointer array (scattered heap):")
	fmt.Printf("  Total time: %.2f ms\n", float64(pointerMicros)/1000.0)
	fmt.Printf("  Time per element: %d ns\n\n", pointerPerElement)
	
	// Calculate difference
	speedup := float64(pointerTime) / float64(valueTime)
	fmt.Printf("Speedup: %.2fx faster for value semantics\n", speedup)
}
