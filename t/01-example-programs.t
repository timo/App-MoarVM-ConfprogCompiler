use v6.c;
use Test;

{
    use App::MoarVM::ConfprogCompiler;

    lives-ok { MAIN(e => q:to/PRG/); }
        version = 1;
        entry profiler_static:
        log = "test log";
        PRG

    lives-ok { MAIN(e => q:to/PRG2/); }
        version = 1;
        entry profiler_static:
        log = "static entrypoint";
        profile = 1;
        entry profiler_dynamic:
        log = "dynamic entrypoint";
        profile = 1;
        PRG2

    lives-ok { MAIN(e => q:to/PRG3/); }
        version = 1;
        entry heapsnapshot:
        log = "heap snapshot entrypoint";
        snapshot = 1;
        PRG3

    lives-ok { MAIN(e => q:to/PRG4/); }
        version = 1;
        entry heapsnapshot:
        log = "heapsnapshot entrypoint";
        entry profiler_static:
        log = "profiler static";
        entry profiler_dynamic:
        log = "dynamic profiler";
        entry jit:
        log = "jit entrypoint";
        entry spesh:
        log = "spesh entrypoint";
        PRG4

    lives-ok { MAIN(e => 'version = 1; entry jit: log = "single line, cool.";'); }
}
done-testing;
