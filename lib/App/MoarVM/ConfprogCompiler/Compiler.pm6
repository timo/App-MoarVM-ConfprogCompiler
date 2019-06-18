unit module App::MoarVM::ConfprogCompiler::Compiler;

use App::MoarVM::ConfprogCompiler::Typesystem;
use App::MoarVM::ConfprogCompiler::Nodes;


# XXX not all builtins are valid after all entrypoints
# XXX some code can be for two entrypoints at once, so unify types if necessa
use MASTOps:from<NQP>;

my %original-op-gen := MAST::Ops.WHO<%generators>;

my %op-gen = %(
    do for %original-op-gen.keys {
        $_ => -> |c { %original-op-gen{$_}(|c); if $*debug { $*MAST_FRAME.dump-new-stuff() } }
    }
);

my %entrypoint-indices = <
    profiler_static
    profiler_dynamic
    spesh
    jit
    heapsnapshot
>.antipairs;

enum SpecialRegister <
    STRUCT_SELECT
    STRUCT_ACCUMULATOR
    FEATURE_TOGGLE
>;

enum RegisterType <
    RegMVMObject
    RegStruct
    RegInteger
    RegString
    RegCString
    RegNum
>;

my %CPTypeToRegType := :{
    CPInt => RegInteger,
    CPString => RegString,
};

sub to-reg-type($type) {
    with %CPTypeToRegType{$type} {
        return $_
    }
    return RegStruct;
}

constant $custom_reg_base = +SpecialRegister::.keys;

#`≪
multi sub compile_coerce($node, $type, :$target!) {
    if $node.type eqv $type {
        my $rhstarget = $*REGALLOC.fresh($type);
        compile_node($node, :target($rhstarget));
        %op-gen<set>($target, $rhstarget);
        $*REGALLOC.release($rhstarget);
    }
    elsif $node.type eqv CPInt {
        if $type eqv CPString {
            my $rhstarget = $*REGALLOC.fresh(RegString);
            compile_node($node, :target($rhstarget));
            %op-gen<coerce_si>($target, $rhstarget);
            $*REGALLOC.release($rhstarget);
        }
        else {
            die "NYI coerce";
        }
    }
    else {
        die "unsupported coerce";
    }
}
≫

multi sub compile_node(SVal $val, :$target!) {
    %op-gen<const_s>($target, $val.value);
}
multi sub compile_node(IVal $val, :$target!) {
    %op-gen<const_i64>($target, $val.value);
}
multi sub compile_node(Var $var, :$target) {
    if $var.scope eq "builtin" {
        given $var.name {
            when "sf" {
                %op-gen<const_s>(0, "");
                %op-gen<getattr_o>($target, STRUCT_ACCUMULATOR, STRUCT_SELECT, "staticframe", 0);
            }
            when "frame" {
                %op-gen<const_s>(0, "");
                %op-gen<getattr_o>($target, STRUCT_ACCUMULATOR, STRUCT_SELECT, "frame", 0);
            }
            default {
                die "builtin variable $var.name() NYI";
            }
        }
    }
    elsif $var.scope eq "my" {
        die "user-specified variables NYI"
    }
    else {
        die "unexpected variable scope $var.scope()";
    }
}

my int $dynamic_label_idx = 1;

sub compile_call(Op $op, :$target) {
    my $funcname = $op.children[0].Str;
    given $funcname {
        when "choice" {
            my $value = $*REGALLOC.fresh(RegNum);
            %op-gen<rand_n>($value);

            my $comparison-value = $*REGALLOC.fresh(RegNum);
            my $comparison-result = $*REGALLOC.fresh(RegInteger);

            my num $step = 1e0 / ($op.children.elems - 1);

            my @individual-labels = Label.new(name => "choice-" ~ $dynamic_label_idx++, type => "internal") xx ($op.children.elems - 2);
            my $end-label = Label.new(name => "choice-exit-" ~ $dynamic_label_idx++, type => "internal");
            @individual-labels.push: $end-label;

            my $current-comparison-literal = $step;

            #ddt $op;

            for $op.children<>[1..*].list Z @individual-labels {
                %op-gen<const_n64>($comparison-value, $current-comparison-literal);
                %op-gen<gt_n>($comparison-result, $value, $comparison-value);
                %op-gen<if_i>($comparison-result, .[1]);
                compile_node(.[0], :$target);
                %op-gen<goto>($end-label);
                compile_node(.[1]);
            }
            compile_node($end-label);
        }
        when "starts-with" | "ends-with" | "contains" | "index" {
            my $haystackreg = $*REGALLOC.fresh(RegString);

            compile_node($op.children[1], target => $haystackreg);

            my $needlereg   = $*REGALLOC.fresh(RegString);

            compile_node($op.children[2], target => $needlereg);

            #my $resultreg = $*REGALLOC.fresh(RegInteger);
            my $resultreg = $target;

            if $funcname eq "contains" | "index" {
                my $positionreg = $*REGALLOC.fresh(RegInteger);
                %op-gen<const_i64_16>($positionreg, 0);
                %op-gen<index_s>($resultreg, $haystackreg, $needlereg, $positionreg);
                # index_s returns -1 on not found, 0 or higher on "found in some position"
                # so we increment by 1 to get zero vs nonzero
                %op-gen<const_i64_16>($positionreg, 1);
                %op-gen<add_i>($resultreg, $resultreg, $positionreg);
                # to get an actual bool result, do the old C trick of
                # negating the value twice
                %op-gen<not_i>($resultreg, $resultreg);
                %op-gen<not_i>($resultreg, $resultreg);
                $*REGALLOC.release($positionreg);
            }
            else {
                my $positionreg = $*REGALLOC.fresh(RegInteger);
                if $funcname eq "starts-with" {
                    %op-gen<const_i64_16>($positionreg, 0);
                }
                elsif $funcname eq "ends-with" {
                    %op-gen<chars>($positionreg, $haystackreg);
                    my $needlelenreg = $*REGALLOC.fresh(RegInteger);
                    %op-gen<chars>($needlelenreg, $needlereg);
                    %op-gen<sub_i>($positionreg, $positionreg, $needlelenreg);
                    $*REGALLOC.release($needlelenreg);
                }
                %op-gen<eqat_s>($resultreg, $haystackreg, $needlereg, $positionreg);
                $*REGALLOC.release($positionreg);
            }

            $*REGALLOC.release($haystackreg);
            $*REGALLOC.release($needlereg);
        }
        when "filename" | "lineno" {
            compile_node($op.children[1], target => STRUCT_ACCUMULATOR);

            %op-gen<getcodelocation>(STRUCT_ACCUMULATOR, STRUCT_ACCUMULATOR);

            my $func = $funcname eq "filename"
                ?? %op-gen<smrt_strify>
                !! %op-gen<smrt_intify>;
            $func($target, STRUCT_ACCUMULATOR);
        }
        default {
            die "Cannot compile call of function $funcname yet"
        }
    }
}

multi sub compile_node(Op $op, :$target) {
    given $op.op {
        when "=" {
            my $lhs = $op.children[0];
            my $rhs = $op.children[1];

            my $rhstarget = $*REGALLOC.fresh($lhs.type);
            compile_node($rhs, target => $rhstarget);

            if $lhs.scope eq "builtin" {
                if $lhs.name eq "log" {
                    %op-gen<say>($rhstarget);
                }
                elsif $lhs.name eq "snapshot" | "profile" {
                    %op-gen<set>(FEATURE_TOGGLE, $rhstarget);
                }
                else {
                    die "builtin variable $lhs.name() NYI";
                }
            }
            else {
                die "variable scope $lhs.scope() NYI";
            }
            $*REGALLOC.release($rhstarget);
        }
        when "stringify" {
            my $child = $op.children[0];

            my $valtarget = $*REGALLOC.fresh(RegCString);

            compile_node($child, target => $valtarget);
            %op-gen<coerce_is>($target, $valtarget);
            $*REGALLOC.release($valtarget);
        }
        when "intify" {
            my $child = $op.children[0];

            my $valtarget = $*REGALLOC.fresh(RegInteger);

            compile_node($child, target => $valtarget);
            %op-gen<smrt_intify>($target, $valtarget);
            $*REGALLOC.release($valtarget);
        }
        when "getattr" {
            my $value = $op.children[0];
            my $attribute = $op.children[1];

            my $targetreg;
            my $targetregtype = to-reg-type($value.type);

            if $targetregtype eqv RegStruct {
                $targetreg = STRUCT_ACCUMULATOR
            }
            else {
                $targetreg = $*REGALLOC.fresh($targetregtype)
            }

            compile_node($value, target => $targetreg);

            # select right struct type
            # this ends up as two noops after the validator has
            # seen it, but the getattr that comes next will use
            # the type identified here for the struct type.
            %op-gen<const_s>(STRUCT_SELECT, $value.type.name);

            %op-gen<getattr_o>($target, $targetreg, STRUCT_SELECT, $attribute, 0);

            if $targetreg != STRUCT_ACCUMULATOR {
                $*REGALLOC.release($targetreg)
            }
        }
        when any(<eq_s ne_s add_i sub_i mul_i div_i>)  {
            my $lhs = $op.children[0];
            my $rhs = $op.children[1];

            my $leftreg = $*REGALLOC.fresh(RegString);
            compile_node($lhs, target => $leftreg);

            my $rightreg = $*REGALLOC.fresh(RegString);
            compile_node($rhs, target => $rightreg);

            %op-gen{$op.op()}($target, $leftreg, $rightreg);

            $*REGALLOC.release($leftreg);
            $*REGALLOC.release($rightreg);
        }
        when "call" {
            compile_call($op, :$target) with $target;
            compile_call($op) without $target;
        }
        when "negate" {
            compile_node($op.children[0], :$target);
            %op-gen<not_i>($target, $target);
        }
        default {
            die "cannot compile $op.op() yet";
        }
    }
}
multi compile_node(Label $label) {
    given $label.type {
        when "user" | "internal" {
            $label.position = $*MAST_FRAME.bytecode.elems;
        }
        when "entrypoint" {
            $*MAST_FRAME.set-entrypoint($label);
        }
    }
}

our sub compile-confprog($unified-ast) is export {

    my $*MAST_FRAME = class {
        has @.bytecode is buf8;
        has str @.strings;
        has @.entrypoints is default(1);

        has %.labelrefs{Any};

        has $.dump-position = 0;

        has $.current-entrypoint;

        method set-entrypoint($label) {
            with $.current-entrypoint {
                %op-gen<exit>(0);
            }
            $label.position = $*MAST_FRAME.add-entrypoint($label.name);
            $!current-entrypoint = $label.name;
        }

        method add-string(str $str) {
            my $found := @!strings.grep($str, :k);
            if $found -> $_ {
                return $_[0]
            }
            @!strings.push: $str;
            @!strings.end;
        }
        method add-entrypoint(str $name) {
            with %entrypoint-indices{$name} {
                given @!entrypoints[$_] {
                    when 1 {
                        $_ = @.bytecode.elems;
                    }
                    default {
                        die "duplicate entrypoint $name";
                    }
                }
            }
            else {
                die "unknown entrypoint $name";
            }
        }
        method compile_label($bytecode, $label) {
            with $label.position {
                die "labels must not appear before their declaration, sorry!"
            }
            %.labelrefs{$label}.push: $bytecode.elems;
            $bytecode.write-uint32($bytecode.elems, 0xbbaabbaabbaabba);
        }

        method finish-labels() {
            for %.labelrefs {
                for .value.list -> $fixup-pos {
                    @!bytecode.write-uint32($fixup-pos, .key.position);
                }
            }
        }

        method dump-new-stuff() {
            for @!bytecode.skip($!dump-position) -> $a, $b {
                state $pos = 0;
                my int $cur-pos = $!dump-position + $pos;
                $pos += 2;

                my int $sixteenbitval = $b * 256 + $a;

                if $pos == 2 {
                    use nqp;

                    my Mu $names := MAST::Ops.WHO<@names>;
                    if $sixteenbitval < nqp::elems($names) {
                        say nqp::atpos_s($names, $sixteenbitval);
                    }
                }

                say "$cur-pos.fmt("0x% 4x") $sixteenbitval.fmt("%04x") ($sixteenbitval.fmt("%05d"))  -- $a.fmt("%02x") $b.fmt("%02x") / $a.fmt("%03d") $b.fmt("%03d")";
            }
            $!dump-position = +@!bytecode;
            say "";
        }
    }.new;

    my $*REGALLOC = class {
        has @!types;
        has @!usage;

        submethod BUILD {
            @!types = [RegString, RegStruct, RegInteger];
            @!usage = [-1 xx $custom_reg_base];
        }

        multi method fresh(RegisterType $type) {
            for 0..* Z @!types Z @!usage {
                if .[1] eqv $type && .[2] == 0 {
                    .[2] = 1;
                    return .[0]
                }
            }
            @!types.push: $type;
            @!usage.push: 1;
            return @!usage.end;
        }
        multi method fresh(CPType $type) {
            self.fresh(to-reg-type($type));
        }
        method release($reg) {
            given @!usage[$reg] {
                when 1 {
                    $_ = 0
                }
                when 0 {
                    die "tried to double-release register $reg";
                }
                when -1 {
                    die "tried to release special register $reg ($(SpecialRegister($reg)))"
                }
                when Any:U {
                    die "tried to free register $reg, but only @!usage.elems() registers were allocated yet";
                }
                default {
                    die "unexpected usage value $_.perl() for register $reg"
                }
            }
        }
    }.new;

    for $unified-ast.list {
        if $_ ~~ Node {
            compile_node($_);
        }
    }
    $*MAST_FRAME.finish-labels();

    my int @entrypoints = $*MAST_FRAME.entrypoints >>//>> 1;

    %(
        :@entrypoints,
        bytecode => $*MAST_FRAME.bytecode,
        strings => $*MAST_FRAME.strings
    );
}
