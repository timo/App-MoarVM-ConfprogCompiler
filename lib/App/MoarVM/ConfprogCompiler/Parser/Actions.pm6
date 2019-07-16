unit module App::MoarVM::ConfprogCompiler::Parser::Actions;

use App::MoarVM::ConfprogCompiler::Nodes;

my %op-to-op = <
    =  bind
    == eq_i
    != ne_i
    eq eq_s
    ne ne_s
    && band_i
    || bor_i
    and band_i
    or bor_i
    xor bxor_i
    + add_i
    - sub_i
    * mul_i
    / div_i
>;

my %prefix-to-op = <
    ~ stringify
    + intify
    ! negate
>;


our class ConfProgActions is export {
    has %.labels;

    method prefixop($/) { make $/.Str }
    method compop($/)   { make %op-to-op{$/.Str} }
    method arithop($/)   { make %op-to-op{$/.Str} }

    method variable:<custom>($/)    { make Var.new( name => $/.Str, scope => "my") }
    method variable:<builtin>($/)   { make Var.new( name => $/.Str, scope => "builtin") }

    method update_op:<logical>($/)    { make $/.Str }
    method update_op:<assignment>($/) { make $/.Str }

    method one_expression:<literal_number>($/) { make IVal.new(value => $/.Str.Int) }
    method one_expression:<literal_number_base16>($/) { make IVal.new(value => $/.Str.Int) }

    method one_expression:<literal_string>($/) {
        die "only very literal strings are allowed; you must not use \\q or \\qq." if $/.Str.contains("\\q");
        use MONKEY-SEE-NO-EVAL;
        # force single-quote semantics
        make SVal.new( value => ("q" ~ $/.Str).&EVAL );
    }

    method postfixish:<attribute>($/) {
        make Op.new( op => "getattr", children => [Any, $<ident>.Str] )
    }
    method postfixish:<positional>($/) {
        make Op.new( op => "getattr", children => [Any, $<one_expression>.ast] )
    }

    method expression:<one>($/) {
        if $<other_expression> && ($<compop> || $<arithop>) {
            make Op.new( op => ($<compop> || $<arithop>).ast,
                children => [
                    $<one_expression>.ast,
                    $<other_expression>.ast,
                ] );
        }
        else {
            make $<one_expression>.ast
        }
    }

    method one_expression:<variable>($/) { make $<variable>.ast }
    method one_expression:<parenthesized>($/) { make $<expression>.ast }

    method one_expression:<prefixed>($/) {
        make Op.new(
            op => %prefix-to-op{$<prefixop>.Str},
            children => [
                $<expression>.ast
            ]);
    }

    method one_expression:<drilldown>($/) {
        my $result = $<variable>.ast;
        for $<postfixish>>>.ast {
            $_.children[0] = $result;
            $result = $_;
        }
        make $result;
    }

    method one_expression:<functioncall>($/) {

        my @positionals;
        my @nameds;

        for @<one_expression> {
            @positionals.push: .ast;
        }

        my $result = Op.new(
            op => "call",
            children => [
                flat $<ident>.Str,
                @positionals, @nameds
            ]);
        make $result;
    }

    method statement:<entrypoint>($/) {
        make Label.new(
            name => $<entrypoint>.Str,
            type => "entrypoint"
        );
    }
    method statement:<label>($/) {
        my $label = Label.new(
            name => $<ident>.Str,
            type => "user"
        );
        with %.labels{$<ident>.Str} {
            die "duplicate definition of label $<ident>.Str()";
        }
        else {
            $_ = $label;
        }
        make $label;
    }

    method statement:<var_update>($/) {
        make Op.new(
            op => $<update_op>.ast,
            children => [
                $<variable>.ast,
                $<expression>.ast,
            ]
        )
    }

    method TOP($/) { make $<statement>>>.ast }
}
