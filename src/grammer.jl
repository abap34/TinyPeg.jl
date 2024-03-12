global DEBUG = false

function setdebug!(b::Bool)
    global DEBUG = b
end

abstract type AbstractParseBlock end
abstract type TerminalExpression <: AbstractParseBlock end
abstract type NonTerminalExpression <: AbstractParseBlock end


struct Grammer{P<:AbstractParseBlock} <: AbstractParseBlock
    expr::P
    builder::Function
end


function status(context::ParseContext, ::Grammer{P}) where {P}
    SPACE = " "
    width = max(length(context.input), 20)

    println("-"^width)
    printstyled("Grammer: $P\n", bold=true, color=:magenta)
    printstyled(" $(context.input) \n", bold=true, color=:blue, underline=true)
    printstyled(SPACE^context.pos, "^\n", color=:green)
    printstyled(SPACE^context.failpos, "^\n", color=:red)

    if context.state == FAIL
        printstyled("Status: FAIL at position $(context.failpos)\n", color=:red)
    elseif context.state == UN
        printstyled("Status: Unfinished\n", color=:yellow)
    elseif context.state == FINISHED
        printstyled("Status: Finished\n", color=:cyan)
    end

    println("-"^width)
end



function match(expr::TerminalExpression, context::ParseContext)::MatchResult end
function parse!(expr::AbstractParseBlock, context::ParseContext)::Union{Nothing,String,Vector{String}} end


function parse!(grammer::Grammer, input::String)
    context = ParseContext(input)
    return parse!(grammer, context)
end


function parse!(grammer::Grammer, context::ParseContext)
    (DEBUG) && (status(context, grammer))
    result = parse!(grammer.expr, context)
    (DEBUG) && (status(context, grammer))
    if isfail(context)
        return nothing
    else
        return grammer.builder(result)
    end
end


function update!(context::ParseContext, result::MatchResult)
    if !(result.success)
        context.state = FAIL
        context.failpos = result.errpos
        return nothing
    end

    context.pos = result.pos
    context.failpos = result.errpos
    context.state = UN

    if context.pos == context.endpos + 1
        context.state = FINISHED
    end

    return result.captured
end


function parse!(expr::TerminalExpression, context::ParseContext)
    update!(context, match(expr, context))
end


struct PStr <: TerminalExpression
    text::String
end


function match(expr::PStr, context::ParseContext)
    if startswith(watching(context), expr.text)
        newpos = context.pos + length(expr.text)
        return MatchResult(true, expr.text, newpos, newpos)
    else
        return MatchResult(false, nothing, context.pos, context.pos)
    end
end


struct PAny <: TerminalExpression end


function match(::PAny, context::ParseContext)
    if context.pos <= context.endpos
        newpos = context.pos + 1
        return MatchResult(true, watching(context)[1], newpos, newpos)
    else
        return MatchResult(false, nothing, context.pos, context.pos)
    end
end


struct PRegex <: TerminalExpression
    regex::Regex
end


function match(expr::PRegex, context::ParseContext)
    m = Base.match(expr.regex, watching(context))
    if m === nothing
        return MatchResult(false, nothing, context.pos, context.pos)
    else
        offset = m.offset
        newpos = context.pos + length(m.match) + offset - 1
        return MatchResult(true, String(m.match), newpos, newpos)
    end
end


struct PNot{P<:AbstractParseBlock} <: NonTerminalExpression
    expr::P
end


function parse!(expr::PNot, context::ParseContext)
    result = match(expr.expr, context)
    if result.success
        return nothing
    else
        return ""
    end
end


struct PSeq{P1<:AbstractParseBlock,P2<:AbstractParseBlock} <: NonTerminalExpression
    expr1::P1
    expr2::P2
end


function PSeq(exprs::AbstractParseBlock...)
    if length(exprs) == 1
        return exprs[1]
    else
        return PSeq(exprs[1], PSeq(exprs[2:end]...))
    end
end


function parse!(expr::PSeq, context::ParseContext)
    pos = context.pos
    captured = parse!(expr.expr1, context)

    if isfail(context)
        context.pos = pos
        return nothing
    end

    pos = context.pos
    captured2 = parse!(expr.expr2, context)

    if isfail(context)
        context.pos = pos
        return nothing
    end

    return [captured, captured2]
end


struct PChoice{P1<:AbstractParseBlock,P2<:AbstractParseBlock} <: AbstractParseBlock
    expr1::P1
    expr2::P2
end


function PChoice(exprs::AbstractParseBlock...)
    if length(exprs) == 1
        return exprs[1]
    else
        return PChoice(exprs[1], PChoice(exprs[2:end]...))
    end
end


function parse!(expr::PChoice, context::ParseContext)
    pos = context.pos

    captured = parse!(expr.expr1, context)

    if isfail(context)
        context.pos = pos
        context.state = UN
        captured = parse!(expr.expr2, context)

        if isfail(context)
            context.pos = pos
            return nothing
        else
            return captured
        end
    else
        return captured
    end
end


struct PMany{P<:AbstractParseBlock} <: AbstractParseBlock
    expr::P
end


function parse!(expr::PMany, context::ParseContext)
    results = []

    while true
        pos = context.pos
        captured = parse!(expr.expr, context)

        if isfail(context)
            if context.pos == context.endpos + 1
                context.state = FINISHED
            else
                context.pos = pos
                context.state = UN
            end

            break
        else
            pos = context.pos
            push!(results, captured)
        end
    end
    return results
end

