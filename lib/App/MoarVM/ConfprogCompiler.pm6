use v6.c;
unit class App::MoarVM::ConfprogCompiler:ver<0.0.6>:auth<cpan:TIMOTIMO>;

use App::MoarVM::ConfprogCompiler::Parser;
use App::MoarVM::ConfprogCompiler::Typesystem::Unifier;
use App::MoarVM::ConfprogCompiler::Compiler;
use App::MoarVM::ConfprogCompiler::Serializer;

our class ConfprogCompiler is export {
    method compile($sourcecode) {
        without $sourcecode {
            die "No source code provided";
        }
        my $parseresult = parse-confprog($sourcecode);
        without $parseresult {
            die "Failed to parse the program";
        }
        my $parse-ast = $parseresult.ast;
        my $unified = unify-ast-types($parse-ast);
        my $compiled = compile-confprog($unified);
        serialize-confprog($compiled);
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

=begin code

confprog-compile -e="version = 1; entry profiler_static: profile = choice(1, 2, 3, 4); log = "hello";' -o=example.mvmconfprog
perl6 --confprog=example.mvmconfprog --profile -e '.say for (^100_000).grep(*.is-prime).tail(5)'

=end code

=head1 DESCRIPTION

C<App::MoarVM::ConfprogCompiler> will parse a domain-specific language for
defining the behavior of specific pluggable moarvm subsystems, such as the
instrumented or heapsnapshot profiler.

A commandline utility named C<confprog-compile> is provided that takes a program
as a filename or a literal string and outputs a hexdump (compatible with
K<xxd -r>) or to an output file passed on the commandline.

=head1 AUTHOR

Timo Paulssen <timonator@perpetuum-immobile.de>

=head1 COPYRIGHT AND LICENSE

Copyright 2019 Timo Paulssen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
