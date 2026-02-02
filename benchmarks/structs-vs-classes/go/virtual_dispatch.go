// Benchmark 2: Interface dispatch vs concrete types
// Run: go run virtual_dispatch.go

package main

import (
	"fmt"
	"time"
)

// Interface (dynamic dispatch)
type Shape interface {
	Area() float64
}

type Circle struct {
	Radius int
}

func (c Circle) Area() float64 {
	return 3.14159 * float64(c.Radius*c.Radius)
}

// Benchmark interface dispatch
func benchmarkInterface(n int, iterations int) time.Duration {
	shapes := make([]Shape, n)
	
	// Initialize with concrete types
	for i := 0; i < n; i++ {
		shapes[i] = Circle{Radius: i}
	}
	
	start := time.Now()
	
	for iter := 0; iter < iterations; iter++ {
		sum := 0.0
		for i := 0; i < n; i++ {
			sum += shapes[i].Area()  // Interface call (dynamic dispatch)
		}
		// Prevent optimization
		if sum < 0 {
			fmt.Println(sum)
		}
	}
	
	return time.Since(start)
}

// Benchmark concrete type (static dispatch)
func benchmarkConcrete(n int, iterations int) time.Duration {
	circles := make([]Circle, n)
	
	// Initialize
	for i := 0; i < n; i++ {
		circles[i] = Circle{Radius: i}
	}
	
	start := time.Now()
	
	for iter := 0; iter < iterations; iter++ {
		sum := 0.0
		for i := 0; i < n; i++ {
			sum += circles[i].Area()  // Direct call (can be inlined)
		}
		// Prevent optimization
		if sum < 0 {
			fmt.Println(sum)
		}
	}
	
	return time.Since(start)
}

func main() {
	const n = 10000000  // 10 million calls
	const iterations = 10
	
	fmt.Println("Benchmarking Go interface vs concrete type dispatch")
	fmt.Printf("Elements: %d\n", n)
	fmt.Printf("Iterations: %d\n", iterations)
	fmt.Printf("Total calls: %d\n\n", n*iterations)
	
	// Warm up
	benchmarkInterface(1000, 10)
	benchmarkConcrete(1000, 10)
	
	// Benchmark interface dispatch
	interfaceTime := benchmarkInterface(n, iterations)
	interfaceMicros := interfaceTime.Microseconds()
	interfacePerCall := interfaceTime.Nanoseconds() / int64(n*iterations)
	
	fmt.Println("Interface dispatch (dynamic):")
	fmt.Printf("  Total time: %.2f ms\n", float64(interfaceMicros)/1000.0)
	fmt.Printf("  Time per call: %d ns\n\n", interfacePerCall)
	
	// Benchmark concrete type
	concreteTime := benchmarkConcrete(n, iterations)
	concreteMicros := concreteTime.Microseconds()
	concretePerCall := concreteTime.Nanoseconds() / int64(n*iterations)
	
	fmt.Println("Concrete type (static dispatch):")
	fmt.Printf("  Total time: %.2f ms\n", float64(concreteMicros)/1000.0)
	fmt.Printf("  Time per call: %d ns\n\n", concretePerCall)
	
	// Calculate speedup
	speedup := float64(interfaceTime) / float64(concreteTime)
	fmt.Printf("Speedup: %.2fx faster for concrete types\n", speedup)
}
