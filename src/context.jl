import Base


@enum State UN FAIL FINISHED


mutable struct ParseContext
    input::String
    pos::Int
    endpos::Int
    failpos::Int
    state::State
end

function Base.show(io::IO, context::ParseContext)
    print(io, "ParseContext(")
    print(io, "input=$(context.input), ")
    print(io, "pos=$(context.pos), ")
    print(io, "endpos=$(context.endpos), ")
    print(io, "failpos=$(context.failpos), ")
    print(io, "state=$(context.state)")
    print(io, ")")
end

function ParseContext(input::String)
    ParseContext(input, 1, length(input), 1, UN)
end

function watching(context::ParseContext)
    return SubString(context.input, context.pos, context.endpos)
end


function isunfinished(context::ParseContext)
    return context.state == UN
end

function isfail(context::ParseContext)
    return context.state == FAIL
end

function isfinished(context::ParseContext)
    return context.state == FINISHED
end


struct MatchResult
    success::Bool
    captured::Union{String,Nothing,Vector{String}}
    pos::Int
    errpos::Int
end


function issuccess(result::MatchResult)
    return result.success
end