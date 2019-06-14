unit module App::MoarVM::ConfprogCompiler::Serializer;

our sub serialize-confprog($stuff) is export {
    my buf8 $result .= new;
    $result.append("MOARVMCONFPROGVER001".encode("utf8").list);
    $result.write-uint32($result.elems, $stuff<strings>.elems);
    for $stuff<strings>.list {
        my $encoded = .encode("utf8");
        die "refusing a string longer than 2**31 bytes: $encoded.elems()" if $encoded.elems > 2**31;
        $result.write-uint32($result.elems, $encoded.elems);
        $result.append($encoded);
    }
    $result.write-uint32($result.elems, $stuff<entrypoints>.elems);
    for $stuff<entrypoints>.list {
        $result.write-int16($result.elems, $_);
    }
    $result.write-uint32($result.elems, $stuff<bytecode>.elems);
    $result.append($stuff<bytecode>);
    $result;
}
