using MapUnroll
using Test

@testset "Basic functionality" begin
    function create_vector(n)
        # Start with an undefined, untyped vector of a known size.
        out = UndefVector{Union{}}(n)
        @unroll 2 for i in 1:n
            # The body creates a value.
            val = i^2
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
    @test v == [1, 4, 9, 16, 25]


    # Test basic summation
    function sum_unrolled3(range)
        s = 0
        @unroll 3 for i in range
            s += i
        end
        s
    end

    function sum_unrolled10(range)
        s = 0
        @unroll 10 for i in range
            s += i
        end
        s
    end
    @test sum_unrolled3(1:10) == sum(1:10)
    @test sum_unrolled10(1:10) == sum(1:10)

    # Loop length is less than N
    @test sum_unrolled10(1:3) == sum(1:3)

    # Loop length is equal to N
    @test sum_unrolled10(1:10) == sum(1:10)


    # Loop is empty
    @test sum_unrolled10(1:0) == 0

    # Loop has one element
    @test sum_unrolled10(1:1) == 1

end

@testset "Macro Hygiene" begin
    # Define variables with the same names as those used inside the macro
    function test_hygiene()
        itr = "outer itr"
        next = "outer next"
        state = "outer state"
        loopend = "outer loopend"

        # The macro should not touch these outer variables
        res = Int[]
        @unroll 2 for i in 1:3
            push!(res, i)
        end

        @test res == [1, 2, 3]
        @test itr == "outer itr"
        @test next == "outer next"
        @test state == "outer state"
    end
    test_hygiene()
end

@testset "Error Handling" begin
    # Macro should reject non-for-loop expressions
    @test_throws LoadError @eval(
        @unroll 2 while true
        end
    )

end
