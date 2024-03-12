float = Grammer(
    PSeq(
        PRegex(r"[0-9]+"),
        PStr("."),
        PRegex(r"[0-9]+")
    ),
    w -> parse(Float64, join([w[1], join(w[2])]))
)


int = Grammer(
    PRegex(r"[0-9]+"),
    w -> parse(Int, w)
)


num = Grammer(
    PChoice(
        float,
        int
    ),
    identity
)


ident = Grammer(
    PRegex(r"^[a-zA-Z_][a-zA-Z0-9_]*"),
    (w) -> Symbol(w)
)


mul = Grammer(
    PSeq(
        PChoice(
            ident,
            num
        ),
        PMany(
            PSeq(
                PChoice(
                    PStr("*"),
                    PStr("/")
                ),
                PChoice(
                    ident,
                    num
                )
            )
        )
    ),
    function (w::AbstractArray)
        lhs = w[1]
        for ex in w[2]
            op, rhs = ex
            lhs = Expr(:call, Symbol(op), lhs, rhs)
        end
        return lhs
    end
)

add = Grammer(
    PSeq(
        PChoice(
            mul,
            num
        ),
        PMany(
            PSeq(
                PChoice(
                    PStr("+"),
                    PStr("-")
                ),
                PChoice(
                    mul,
                    num
                )
            )
        )
    ),
    function (w::AbstractArray)
        lhs = w[1]
        for ex in w[2]
            op, rhs = ex
            lhs = Expr(:call, Symbol(op), lhs, rhs)
        end
        return lhs
    end
)


assign = Grammer(
    PSeq(
        ident,
        PStr("="),
        PChoice(
            add,
            num
        )
    ),
    w -> Expr(:(=), w[1], w[2][2])
)

call = Grammer(
    PSeq(
        ident,
        PStr("("),
        PMany(
            PChoice(
                num,
                ident
            )
        ),
        PStr(")")
    ),
    (w) -> Expr(:call, w[1], w[2][2][1][1])
)

expr = Grammer(
    PChoice(
        call,
        assign,
        add,
    ),
    identity
)

source = Grammer(
    PSeq(
        expr,
        PMany(
            PSeq(
                PStr(";"),
                expr
            )
        )
    ),
    function (w)
        Expr(:let,
            Expr(:block),
            Expr(:block,
                [w[1], (x -> getindex(x, 2)).(w[2])...]...
            )
        )
    end
)

ast = parse!(source, "a=1;b=2;c=3;d=a+b*c/3;println(d)")

println(ast)

eval(ast)
