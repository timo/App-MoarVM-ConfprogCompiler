[![Build Status](https://travis-ci.org/timo/App-MoarVM-ConfprogCompiler.svg?branch=master)](https://travis-ci.org/timo/App-MoarVM-ConfprogCompiler)

NAME
====

App::MoarVM::ConfprogCompiler - Compiler for MoarVM's confprog subsystem

SYNOPSIS
========

```perl6
use App::MoarVM::ConfprogCompiler;

ConfprogCompiler.compile($sourcecode);
```

    confprog-compile -e="version = 1; entry profiler_static: profile = choice(1, 2, 3, 4); log = "hello";' -o=example.mvmconfprog
    perl6 --confprog=example.mvmconfprog --profile -e '.say for (^100_000).grep(*.is-prime).tail(5)'

DESCRIPTION
===========

`App::MoarVM::ConfprogCompiler` will parse a domain-specific language for defining the behavior of specific pluggable moarvm subsystems, such as the instrumented or heapsnapshot profiler.

A commandline utility named `confprog-compile` is provided that takes a program as a filename or a literal string and outputs a hexdump (compatible with xxd -r) or to an output file passed on the commandline.

AUTHOR
======

Timo Paulssen <timonator@perpetuum-immobile.de>

COPYRIGHT AND LICENSE
=====================

Copyright 2019 Timo Paulssen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

