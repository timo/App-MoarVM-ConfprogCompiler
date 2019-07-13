constant @entrypoints = <profiler_static profiler_dynamic spesh jit heapsnapshot>;

grammar ConfProg {
    regex TOP {
        ["version" \s* "=" \s* "1" <.eol> || { die "Program has to start with a version. Only version = 1 is supported here" }]:
        <statement>+ %% <.eol>
    }

    regex eol { \s* ';' \n* \s* | \s* \n+ \s* | \s* \n* $$ | <?after ':'> \s* }

    proto regex statement { * }

    regex statement:<var_update> {
        <variable> \s+ <update_op> \s+ <expression>
    }

    regex statement:<entrypoint> {
        'entry' \s+ {} [$<entrypoint>=[
            @entrypoints
        ] || $<rubbish>=<-[:]>* { die "don't know this entrypoint: $/<rubbish>.Str.perl(), try one of: @entrypoints.join(", ")" }] \s*
        ":"
    }

    regex statement:<continue> {
        'continue'
    }

    regex statement:<label> {
        <ident> \s* ':'
    }

    proto regex variable { * }

    regex variable:<custom> {
        '$' <.ident>
    }
    regex variable:<builtin> {
        <.ident>
    }

    proto regex update_op { * }

    regex update_op:<logical> {
        '|=' | '&='
    }

    regex update_op:<assignment> {
        '='
    }

    proto regex expression { * }

    proto regex one_expression { * }

    regex one_expression:<literal_number> {
        <[1..9]> '_'? <[0..9]>* % '_'? | 0
    }
    regex one_expression:<literal_number_base16> {
        "0x" [<[1..9a..fA..F]> '_'? <[0..9a..fA..F]>* % '_'? | 0]
    }

    regex one_expression:<literal_string> {
        | '"' [ <-["]> | \\ \" ]+ '"'
        | "'" [ <-[']> | \\ \' ]+ "'"
    }

    regex one_expression:<drilldown> {
        <variable> <postfixish>+
    }

    regex one_expression:<variable> {
        <variable>
    }

    regex expression:<one> {
         <one_expression> [\s* [<compop>|<arithop>] \s* <other_expression=.one_expression>]?
    }

    regex one_expression:<parenthesized> {
        '(' \s* <expression> \s* ')'
    }
    regex one_expression:<prefixed> {
        <prefixop> '(' \s* <expression> \s* ')'
    }

    regex one_expression:<functioncall> {
        <ident> '(' <one_expression>* %% [\s* ',' \s*] ')'
    }

    proto regex postfixish { * }
    regex postfixish:<attribute> {
        '.' <ident>
    }
    regex postfixish:<positional> {
        '.' "[" <.one_expression> "]"
    }

    regex compop {
        [
        | "eq"
        | "ne"
        | '&&'
        | '||'
        | "and"
        | "or"
        ]
    }

    regex arithop {
        | "+"
        | "-"
        | "*"
        | "/"
    }

    regex prefixop {
        [
        | '!'
        | '+'
        | '~'
        ]
    }
}

