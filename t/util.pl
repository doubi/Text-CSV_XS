use strict;

sub _readable
{
    join "", map {
	my $cp = ord $_;
	$cp >= 0x20 && $cp <= 0x7e
	    ? $_
	    : sprintf "\\x{%02x}", $cp;
	} split m//, $_[0];
    } # _readable

sub is_binary
{
    my ($str, $exp, $tst) = @_;
    if ($str eq $exp) {
	ok (1,		$tst);
	}
    else {
	my ($hs, $he) = map { _readable $_ } $str, $exp;
	is ($hs, $he,	$tst);
	}
    } # is_binary

1;
