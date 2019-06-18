unit module App::MoarVM::ConfprogCompiler::Typesystem;

our class CPType is export { ... }

my \CPInt    = CPType.new(name => "Int", :numeric, :stringy);
my \CPNum    = CPType.new(name => "Num", :numeric, :stringy);
my \CPString = CPType.new(name => "String", :stringy);
my \CString  = CPType.new(name => "CString", :stringy);

my \MVMStaticFrame = CPType.new(name => "MVMStaticFrame",
    attributes => {
        cu            => "MVMCompUnit",
        env_size      => CPInt,
        work_size     => CPInt,
        num_lexicals  => CPInt,
        cuuid         => CPString,
        name          => CPString,
        outer         => "MVMStaticFrame",
    });

my \MVMCompUnit = CPType.new(name => "MVMCompUnit",
    attributes => {
        hll_name     => CPString,
        filename     => CPString,
    });

my \MVMFrame = CPType.new(name => "MVMFrame",
    attributes => {
        outer        => "MVMFrame",
        caller       => "MVMFrame",
        params       => "MVMArgProcContext",
        return_type  => CPInt,
        static_info  => MVMStaticFrame,
    });

my \MVMThreadContext = CPType.new(name => "MVMThreadContext",
    attributes => {
        thread_id   => CPInt,
        num_locks   => CPInt,
        cur_frame   => MVMFrame,
    });

our %typesystem;

our class CustomDDTOutput {
    has $.ddt_get_header;
    has $.ddt_get_elements;
}

our class CPType is export {
    my %typesystem-fixups{Any};

    has Str $.name;

    has %.attributes;
    has CPType $.positional;
    has CPType $.associative;

    has Bool $.numeric;
    has Bool $.stringy;

    method ddt_get_header {
        "CPType $.name()$( " :numeric" if $.numeric )$( " :stringy" if $.stringy ) "
    }
    method ddt_get_elements {
        []
    }

    method TWEAK {
        %typesystem{$.name} = self;
        for %!attributes -> $p {
            if $p.value ~~ Str {
                with %typesystem{$p.value} {
                    $p.value = $_
                }
                else {
                    %typesystem-fixups{$p.value}.push: (self, $p.key);
                }
            }
        }
        for %typesystem-fixups{self.name}:v {
            .[0].attributes{.[1]} = self;
        }
    }
}

