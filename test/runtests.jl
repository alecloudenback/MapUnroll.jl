using MapUnroll
using Test

@testset "MapUnroll.jl" begin
    # Write your tests here.
end


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
