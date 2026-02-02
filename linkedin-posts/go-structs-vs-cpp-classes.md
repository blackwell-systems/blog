# LinkedIn Post: Go Structs vs C++ Classes

"Structs with methods are just classes with a different name."

This was the most common pushback to my multicore-killed-OOP post. Bruce Perens (Open Source founder) said it. Dozens of commenters agreed.

If structs and classes were the same, the CPU-level costs would be identical.

They're not.

🗂️ What's inside:

🔹 **Memory layout:** Contiguous arrays vs pointer chasing (4-5× speedup)
🔹 **Virtual dispatch:** Static calls vs vtable lookups (8-15× speedup)
🔹 **Allocation:** Stack vs heap operations (25-40× speedup)
🔹 **Inheritance:** Forced indirection vs optional polymorphism
🔹 **Method receivers:** Explicit mutation visibility (value vs pointer)
🔹 **Construction:** Simple assignment vs complex semantics
🔹 **Memory overhead:** Zero hidden pointers vs +8 bytes per object

Each section shows what the processor actually executes: cache lines, CPU cycles, memory addresses.

The difference isn't capability - C++ experts write data-oriented code too. The difference is defaults:

+ **Go:** Concrete types, contiguous memory, static calls (path of least resistance)
+ **C++:** Once you design around inheritance/virtuals, indirection becomes pervasive

Processing 1M objects:
+ C++ (inheritance pattern): 80-120ms (pointer chasing, vtable lookups)
+ Go (concrete types): 10-15ms (sequential memory, direct calls)
+ Go (interfaces): 80-120ms (same costs as C++ when you opt in)

Go makes dynamic dispatch opt-in. C++ makes it pervasive in OO designs.

This isn't about "which language is better." It's about understanding what executes at the hardware level.

📚 Full breakdown with assembly-level details: https://blog.blackwell-systems.com/posts/go-structs-not-cpp-classes/

❔ For C++ developers: Do you design around inheritance hierarchies, or do you prefer composition with concrete types? ❔

#Go #Cpp #SystemsProgramming #PerformanceEngineering #SoftwareArchitecture #Programming #ComputerScience
