using Test
using Dates
using CSV

# This file can run directly with `julia --project=. test/date_parsing.jl`.
module DateParsingFixture
include(joinpath(@__DIR__, "..", "render_gantt.jl"))
end
using .DateParsingFixture: parse_plan_date

@testset "Plan dates from CSV" begin
    rows = CSV.File(IOBuffer("Start_Date,Target_Date\n2024-06,2025-3\n2025-03,2026-02\n"))
    @test parse_plan_date(rows[1].Start_Date) == Date(2024, 6, 1)
    @test parse_plan_date(rows[1].Target_Date) == Date(2025, 3, 1)
    @test parse_plan_date(rows[2].Start_Date) == Date(2025, 3, 1)
    @test parse_plan_date(rows[2].Target_Date) == Date(2026, 2, 1)
    @test parse_plan_date(SubString("2025-3", 1, 6)) == Date(2025, 3, 1)
    @test parse_plan_date("2025-03-12") == Date(2025, 3, 12)
    @test parse_plan_date(Date(2025, 3, 12)) == Date(2025, 3, 12)
    @test_throws ArgumentError parse_plan_date(missing)
    @test_throws ArgumentError parse_plan_date("")
    @test_throws ArgumentError parse_plan_date("2025-13")
end
