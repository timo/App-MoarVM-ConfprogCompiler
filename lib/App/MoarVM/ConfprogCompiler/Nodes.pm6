unit module App::MoarVM::ConfprogCompiler::Nodes;

use App::MoarVM::ConfprogCompiler::Typesystem;

our class Node is export {
    has @.children;
}

our class Op is Node is export {
    has Str $.op;
    has $.type is rw;
}
our class Var is Node is export {
    has $.name;
    has $.scope;
    has $.type is rw;

    method ddt_get_elements {
        ('$.name', " = ", $.name),
        (('$.type', " = ", $.type) if $.type)
    }
}
our class SVal is Node is export {
    has Str $.value;

    method ddt_get_header { "String Value ($.value.perl())" }
    method ddt_get_elements { [] }

    method type { %App::MoarVM::ConfprogCompiler::Typesystem::typesystem<String> }
}
our class IVal is Node is export {
    has Int $.value;

    method ddt_get_header { "Int Value ($.value)" }

    method ddt_get_elements { [] }

    method type { %App::MoarVM::ConfprogCompiler::Typesystem::typesystem<Int> }
}
our class Label is Node is export {
    has $.name;
    has $.type;
    has $.position is rw; # stores bytecode offset during generation
}

