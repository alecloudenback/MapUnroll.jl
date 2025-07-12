# MapUnroll

[![Build Status](https://github.com/alecloudenback/MapUnroll.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/alecloudenback/MapUnroll.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/alecloudenback/MapUnroll.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/alecloudenback/MapUnroll.jl)


## Quickstart

To avoid issues and ensure performance with `map`s that use intermediate variables. Users should turn this pattern:

```julia
function simulate(n)
    x = 0.

    map(1:n) do i
        x += exp(i)
        (timestep=i,state=x)
    end

end
```

Into this:

```julia
using MapUnroll

function simulate_unroll(n)
    out = UndefVector{Union{}}(n)
    x = 0.0
    @unroll 2 for i ∈ 1:n
        x += exp(i)
        out = setindex!!(out, (timestep=i,state=x), i)
    end
    out
end
```

## Explanation

This package addresses situations where you would like to map over a collection and return a concretely typed array that depends on some intermediate variables. For example:

```julia
function simulate(n)
    x = 0.

    map(1:n) do t
        x += exp(i)
        (timestep=t,state=x)
    end

end
```

In the above code, `x` is effectively a global variable with respect to the closure created to the inner `map`. This means that `x` get's "boxed" and is wrapped in a mutable container for use within the map's loop.

Another potential problem is that `map` does not guarantee execution in sequential order, meaning that our simulation could end up being calculated out-of-order.

An alternative is to write a `for` loop. However, the user then needs to take care to create the appropriate output container. For simple types this may work, but for complex types we would prefer that the compiler infer what the output `eltype` of our output vector should be.

`@unroll` addresses this by 'unrolling' the loop, or making the first couple (default `N=2`) iterations occur before the `for` loop actually begins, thus letting the compiler calculate the type of the object that will be placed into the output vector.

Then, from MicroCollections.jl (`UndefVector`) and BangBang.jl (`setindex!!`), the output container can be efficiently expanded by the compiler to return type stable and performant code. `UndefVector` and `setindex!!` are re-exported from MapUnroll.jl for convenience.

Comparing the two versions of the simulation above:

The original `simulate` does not avoid boxing the intermediate variable:

```julia-repl
julia> @code_warntype simulate(100)
...
Locals
  #15::var"#15#16"
  x::Core.Box
Body::Vector
1 ─       (x = Core.Box())
│   %2  = x::Core.Box
│         Core.setfield!(%2, :contents, 0.0)
│   %4  = Main.map::Core.Const(map)
│   %5  = Main.:(var"#15#16")::Core.Const(var"#15#16")
│   %6  = x::Core.Box
│         (#15 = %new(%5, %6))
│   %8  = #15::var"#15#16"
│   %9  = (1:n)::Core.PartialStruct(UnitRange{Int64}, Any[Core.Const(1), Int64])
│   %10 = (%4)(%8, %9)::Vector
└──       return %10
```

However `simulate_unroll` avoids this and has faster performance as a result:

```julia-repl
julia> using BenchmarkTools
julia> @btime simulate(100)
  9.167 μs (407 allocations: 11.12 KiB)
julia> @btime simulate_unroll(100)
  233.583 ns (2 allocations: 1.62 KiB)
```

Credit:

The original `@unroll` macro was developed by [Mason Protter](https://github.com/MasonProtter)