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

DESCRIPTION
===========

App::MoarVM::ConfprogCompiler will parse a domain-specific language for defining the behavior of specific pluggable moarvm subsystems, such as the instrumented or heapsnapshot profiler.

AUTHOR
======

Timo Paulssen <timonator@perpetuum-immobile.de>

COPYRIGHT AND LICENSE
=====================

Copyright 2019 Timo Paulssen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

