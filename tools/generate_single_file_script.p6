use File::Find;

my @files = find(dir => "lib", name => *.ends-with("pm6"));

my %modules;
my %dependencies;

for @files -> $fn {
    next if $fn.IO.d;
    my $c = $fn.IO.slurp;
    note "working on $fn";
    my $modname;

    $c.=subst(/« use \s+ v6.*?\;/, "");

    if $c.contains: "unit " {
        $c = $c.subst(/« unit \s* (.*?) [":ver<".*?">:auth<".*?">"]?\;/,
            { $modname = $_[0].Str.words.tail; $_[0].Str ~ q[ {] }) ~ "\n}"
    }
    else {
        $modname = $c.match(/« module <("App::MoarVM::ConfprogCompiler".*?)>\;/).Str;
    }

    die "could not determine what module this is" unless $modname;
    note "  module ($modname)\n";

    %dependencies{$modname} = [];
    #$c .= subst(/^^ "=begin " (\w+) .*? "=end " $0 $/, "");
    $c .= subst(/\s*use\s+("App::MoarVM::ConfprogCompiler".*?)\;/, {
        if $_[0].Str ne $modname {
            note "  depends on $_[0].Str()";
            %dependencies{$modname}.push: $_[0].Str;
            "\nimport $_[0].Str();"
        }
        else {
            "\nuse $_[0].Str()";
        }
    }, :g);
    %modules{$modname} = $c;
    note "";
}

note "writing out modules in dependency order...";

my %written_out;
while %modules > %written_out {
    for %dependencies.pairs.grep({ .value (<=) %written_out }) {
        if .key !(elem) %written_out {
            say %modules{.key};

            note "  $_.key()";
        }
        %written_out{.key} = 1
    }
}

note "done\n";

note "concatenating script from bin/";

"bin/confprog-compile".IO.slurp.subst(/ ^^ "#!" .*? $$ /, "").subst(/« use \s+ v6 .*? \;/, "").subst(/« <( use )> \s+ "App::MoarVM::ConfprogCompiler" /, "import").say;

note "single-file script created!";
