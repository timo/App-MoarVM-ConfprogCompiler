unit module App::MoarVM::ConfprogCompiler::Typesystem::Unifier;

use App::MoarVM::ConfprogCompiler::Typesystem;
use App::MoarVM::ConfprogCompiler::Nodes;

my \CPString = %App::MoarVM::ConfprogCompiler::Typesystem::typesystem<String>;
my \CPInt = %App::MoarVM::ConfprogCompiler::Typesystem::typesystem<Int>;
my \MVMFrame = %App::MoarVM::ConfprogCompiler::Typesystem::typesystem<MVMFrame>;
my \MVMStaticFrame = %App::MoarVM::ConfprogCompiler::Typesystem::typesystem<MVMStaticFrame>;

my %targets = %(
    profile => CPInt,
    log => CPString,
    snapshot => CPInt,
);

my %builtins = %(
    sf => MVMStaticFrame,
    frame => MVMFrame,
    time => CPInt,
);

our proto sub unify_type($) is export {*}

multi sub unify_type(Op $node) {
    given $node.op {
        when "getattr" {
            my $source = $node.children[0];
            my $attribute = $node.children[1];
            unify_type($source) unless defined $source.type;
            die "how did you get a getattr node with a non-string attribute name?" unless $attribute ~~ Str;
            die "don't have a type for this" unless $source.type ~~ CPType:D;
            with $source.type.attributes{$attribute} {
                $node.type = $_;
                return $_;
            }
            else {
                die "type $source.type.name() doesn't have an attribute $attribute" 
            }
        }
        when "|=" | "&=" {
            my $source = $node.children[1];
            unify_type($source) unless defined $source.type;
            die "can only use $node.op() with something that can intify" unless defined $source.type && $source.type.numeric;
            $node.type = CPInt;
        }
        when any(<eq_s ne_s>) {
            my $lhs = $node.children[0];
            my $rhs = $node.children[1];
            for $lhs, $rhs {
                .&unify_type() unless defined .type;
            }
            die "lhs of string op must be stringy" unless $lhs.type.stringy;
            die "rhs of string op must be stringy" unless $rhs.type.stringy;
            $node.type = CPInt;
        }
        when any(<band_i bor_i bxor_i add_i sub_i mul_i div_i eq_i ne_i>) {
            my $lhs = $node.children[0];
            my $rhs = $node.children[1];

            $lhs.&unify_type without $lhs.type;
            $rhs.&unify_type without $rhs.type;

            die "arguments to $node.op() must be numericable" unless $lhs.type.numeric && $rhs.type.numeric;
            $node.type = CPInt;
        }
        when "=" {
            my $lhs = $node.children[0];
            my $rhs = $node.children[1];

            die "can only assign to vars, not { try $lhs.type.name() orelse $lhs.^name }" unless $lhs ~~ Var;

            $rhs.&unify_type() without $rhs.type;

            if $lhs.scope eq "my" {
                with %*LEXPAD{$lhs.name} {
                    die "cannot assign $rhs.type.name() to variable $lhs.name(), it was already typed to accept only $_.type.name()" unless $rhs.type eqv .type;
                }
                else {
                    %*LEXPAD{$lhs.name} = $rhs;
                }
            }
            elsif $lhs.scope eq "builtin" {
                with %targets{$lhs.name} {
                    $lhs.type = %targets{$lhs.name};
                    die "type mismatch assigning to output variable $lhs.name(); expected $_.name(), but got a $rhs.?type.?name()" unless $_ eqv $rhs.type;
                }
                else {
                    die "target $lhs.name() not known (did you mean to declare a custom variable \$$lhs.name()";
                }
            }
        }
        when "stringify" | "intify" {
            $node.children[0].&unify_type;

            $node.type =
                ($node.op eq "stringify"
                    ?? CPString
                    !! ($node.op eq "intify"
                        ?? CPInt
                        !! die "what"));
        }
        when "negate" {
            $node.children[0].&unify_type;

            die "negate only works on integers ATM. sorry." unless $node.children[0].type eqv CPInt;

            $node.type = CPInt;
        }
        when "call" {
            # Go by first child, it ought to be a string with the function name.
            my $funcname = $node.children[0];
            given $funcname {
                when "choice" {
                    $node.type = CPInt;
                }
                when "starts-with" | "ends-with" | "contains" | "index" {
                    $node.children[1].&unify_type() without $node.children[1].type;
                    $node.children[2].&unify_type() without $node.children[2].type;
                    $node.type = CPInt;
                    die "$funcname only takes two arguments" unless
                        $node.children == 3;
                    die "$funcname requires two strings as arguments" unless $node.children[1&2].type eqv CPString;
                }
                when "filename" | "lineno" {
                    $node.children[1].&unify_type() without $node.children[1].type;

                    die "$funcname requires a single argument" unless $node.children == 2;
                    die "$funcname requires a MVMStaticFrame, not a $node.children[1].type.name()" unless $node.children[1].type eqv MVMStaticFrame;

                    if $funcname eq "filename" {
                        $node.type = CPString;
                    }
                    else {
                        $node.type = CPInt;
                    }
                }
                default {
                    die "function call to $funcname.perl() NYI, typo'd, or something else is wrong";
                }
            }
        }
        default {
            warn "unhandled node op $node.op() in unify_type for an Op";
            return Any;
        }
    }
}
multi sub unify_type(Var $var) {
    with %builtins{$var.name} {
        $var.type = $_
    }
    else {
        with %*LEXPAD{$var.name} {
            $var.type = .type;
        }
        else {
            die "cannot figure out type of variable $var.name()";
        }
    }
}
multi sub unify_type(Any $_) {
    Any
}

our sub unify-ast-types($ast) is export {
    my %*LEXPAD;
    for $ast.list {
        unify_type($_);
    }
    $ast
}
