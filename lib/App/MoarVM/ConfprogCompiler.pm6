use v6.c;
unit class App::MoarVM::ConfprogCompiler:ver<0.0.1>:auth<cpan:TIMOTIMO>;

use App::MoarVM::ConfprogCompiler::Parser;
use App::MoarVM::ConfprogCompiler::Typesystem::Unifier;
use App::MoarVM::ConfprogCompiler::Compiler;

use Data::Dump::Tree;

our class ConfprogCompiler is export {
    method compile($sourcecode) {
        my $parseresult = parse-confprog($sourcecode);
        my $parse-ast = $parseresult.ast;
        my $unified = unify-ast-types($parse-ast);
        my $result = compile-confprog($unified);
    }
}

proto sub MAIN(|) is export(:MAIN) {*}

multi sub MAIN($filename, Bool :$*debug) {
    ConfprogCompiler.compile($filename.IO.slurp);
}

multi sub MAIN(:$e, Bool :$*debug) {
    ConfprogCompiler.compile($e);
}

=begin pod

=head1 NAME

App::MoarVM::ConfprogCompiler - Compiler for MoarVM's confprog subsystem

=head1 SYNOPSIS

=begin code :lang<perl6>

use App::MoarVM::ConfprogCompiler;

ConfprogCompiler.compile($sourcecode);

=end code

=head1 DESCRIPTION

App::MoarVM::ConfprogCompiler will parse a domain-specific language for
defining the behavior of specific pluggable moarvm subsystems, such as the
instrumented or heapsnapshot profiler.

=head1 AUTHOR

Timo Paulssen <timonator@perpetuum-immobile.de>

=head1 COPYRIGHT AND LICENSE

Copyright 2019 Timo Paulssen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
