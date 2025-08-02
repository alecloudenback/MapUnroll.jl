# MapUnroll.jl

[![Build Status](https://github.com/alecloudenback/MapUnroll.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/alecloudenback/MapUnroll.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/alecloudenback/MapUnroll.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/alecloudenback/MapUnroll.jl)

`MapUnroll.jl` provides the `@unroll` macro to help write performant, type-stable, and order-dependent loops without needing to manually define the output container.

## The Problem: Stateful `map` Operations

Consider a simulation where each step depends on the result of the previous one. A naive implementation using `map` might look like this:

```julia
function simulate(n)
    x = 0.0

    map(1:n) do i
        x += exp(i)
        (timestep=i, state=x)
    end
end
```

This pattern has two significant issues:

1.  **Performance:** The variable `x` is closed over and "boxed" (wrapped in a mutable container) by the compiler, leading to type instability and poor performance.
2.  **Correctness:** `map` does not guarantee sequential execution. For a stateful calculation like this, the order of operations is critical, meaning `map` could produce an incorrect result.

## The Solution: `@unroll`

`MapUnroll.jl` solves both problems by combining the guaranteed execution order of a `for` loop with automatic output type inference.

To fix the `simulate` function, we use the `@unroll` macro and utilities re-exported for convenience from `BangBang.jl` and `MicroCollections.jl`.

```julia
using MapUnroll

function simulate_unroll(n)
    out = UndefVector{Union{}}(n)
    x = 0.0

    @unroll 2 for i ∈ 1:n
        x += exp(i)
        out = setindex!!(out, (timestep=i, state=x), i)
    end
    out
end
```

### How it Works

The `@unroll` macro "unrolls" the first few iterations of the loop (default is 2). This allows the Julia compiler to observe the type of the object being created.

1.  From the first iteration, the compiler infers the concrete `eltype` of the output.
2.  `setindex!!` then creates a new output container (`Vector`) with that specific `eltype`.
3.  The rest of the loop populates the new, type-stable vector.

This avoids the boxing and performance issues of the `map` approach, while the `for` loop ensures correctness by executing in sequence.

### Performance Comparison

The `@unroll` version avoids the `Core.Box` allocation and is significantly faster.

**Original `simulate`:**
```julia-repl
julia> @code_warntype simulate(100)
...
Locals
  #15::var"#15#16"
  x::Core.Box
Body::Vector
1 ─       (x = Core.Box())
...
```
```julia-repl
julia> using BenchmarkTools
julia> @btime simulate(100)
  9.167 μs (407 allocations: 11.12 KiB)
```

**`simulate_unroll` with MapUnroll.jl:**
```julia-repl
julia> @btime simulate_unroll(100)
  233.583 ns (2 allocations: 1.62 KiB)
```

## Comparison with Other Approaches

| Method | Performance | Correctness (Order) | When to Use |
| :--- | :--- | :--- | :--- |
| **`map` with closure** | Poor (boxing) | No | Not recommended for stateful loops. |
| **`map` with `Ref`** | Good | No | When order doesn't matter but you need to mutate a value. |
| **`accumulate`** | Good | Yes | An excellent, idiomatic choice for this specific simulation pattern, but can get verbose and unweildy when the current state gets complex. |
| **`@unroll` (this package)** | Good | Yes | For developers who prefer an explicit `for` loop, or for complex loop bodies where `accumulate` is less natural. |

While using a `Ref(x)` can solve the boxing problem, it does not solve the execution order problem with `map`. For stateful patterns, idiomatic functional approaches like `accumulate` are also a great option. `@unroll` provides a general-purpose tool that gives the developer control over the loop structure while delegating the tedious parts of output container creation to the compiler.

## Credit

The original `@unroll` macro was developed by [Mason Protter](https://github.com/MasonProtter).

