module TinyPeg

include("context.jl")
include("grammer.jl")

export
    parse!,
    Grammer, 
    PStr,
    PSeq, 
    PChoice, 
    PMany, 
    PRegex, 
    PNot, 
    PAny,
    setdebug!

end
