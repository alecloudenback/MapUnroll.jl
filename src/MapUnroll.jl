module MapUnroll

using MicroCollections
using Reexport


export @unroll
@reexport using MicroCollections: UndefVector
@reexport using BangBang: setindex!!

"""
    @unroll N for_loop

Unroll the first `N` iterations of a for loop, with remaining iterations handled by a regular loop.

This macro takes a for loop and explicitly expands the first `N` iterations, which can improve 
performance and type stability, particularly when building collections where the first few 
iterations determine the container's type.

# Arguments
- `N::Int`: Number of loop iterations to unroll (must be a compile-time constant)
- `for_loop`: A standard for loop expression

# How it works
The macro transforms:
```julia
@unroll 2 for i in 1:n
    # body
end
```

into code that is roughly equivalent to:

```julia
let
    itr = 1:n
    next = iterate(itr)

    # First iteration (unrolled)
    if next === nothing
        @goto loopend
    end
    i, state = next
    # body
    next = iterate(itr, state)

    # Second iteration (unrolled)
    if next === nothing
        @goto loopend
    end
    i, state = next
    # body
    next = iterate(itr, state)

    # Remaining iterations in a while loop
    while next !== nothing
        i, state = next
        # body
        next = iterate(itr, state)
    end

    @label loopend
end
```

By explicitly writing out the first few iterations, the Julia compiler can often infer the types of variables created within the loop body. This is especially beneficial when building a collection (e.g., an array of results), as the type of the collection can be determined from the first element(s), avoiding the performance cost of starting with an abstractly-typed or empty container.

The macro uses the `iterate` protocol directly and `@goto` to efficiently handle iterators that may have fewer than `N` elements.

# Example
```julia
using BangBang, MicroCollections

# A function that builds a vector where the output type is not known upfront.
function create_vector(n)
    # Start with an undefined, untyped vector of a known size.
    out = UndefVector{Union{}}(n)
    @unroll 2 for i in 1:n
        # The body creates a value.
        val = i
        # `setindex!!` from BangBang.jl will update the vector and its type.
        # After the first iteration, `out` will become a `Vector{Int}`.
        # The unrolling helps the compiler see this transformation and produce
        # more specialized, faster code for the rest of the loop.
        out = setindex!!(out, val, i)
    end
    return out
end

# The result is a concretely typed vector.
v = create_vector(5)
println(v)      # [1, 2, 3, 4, 5]
println(typeof(v)) # Vector{Int64}
```
"""
macro unroll(N::Int, loop)
    Base.isexpr(loop, :for) || error("only works on for loops")
    Base.isexpr(loop.args[1], :(=)) || error("This loop pattern isn't supported")
    val, itr = esc.(loop.args[1].args)
    body = esc(loop.args[2])
    @gensym loopend
    label = :(@label $loopend)
    goto = :(@goto $loopend)
    out = Expr(:block, :(itr = $itr), :(next = iterate(itr)))
    unrolled = map(1:N) do _
        quote
            isnothing(next) && @goto loopend
            $val, state = next
            $body
            next = iterate(itr, state)
        end
    end
    append!(out.args, unrolled)
    remainder = quote
        while !isnothing(next)
            $val, state = next
            $body
            next = iterate(itr, state)
        end
        @label loopend
    end
    push!(out.args, remainder)
    return out
end


end
