package Text::CSV_XS;

# Copyright (c) 1997 Alan Citterman. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

################################################################################
# HISTORY
#
# Written by:
#    Alan Citterman <alan@mfgrtl.com>
#
# Version 0.01  06/05/1997
#    original version
#
#         0.10  01-May-1998  Moved parsing and decoding into XS; added
#                            quote_char, escape_char, sep_char and binary
#                            mode, print and getline methods.
#                            Jochen Wiedmann <joe@ispsoft.de>
#
#         0.11  12-May-1998  Added $csv->{'eol'} and
#                            $csv->{'quote_char'} = undef
#                            Jochen Wiedmann <joe@ispsoft.de>
#
#         0.12  11-Jun-1998  Decode now checks for integer or real types.
#                            Jochen Wiedmann <joe@ispsoft.de>
#
############################################################################

require 5.004;
use strict;

require DynaLoader;
use vars qw($VERSION @ISA);

$VERSION =     '0.12';
@ISA =         qw(DynaLoader);


############################################################################
#
# version
#
#    class/object method expecting no arguments and returning the version
#    number of Text::CSV.  there are no side-effects.
#
############################################################################
sub version {
  return $VERSION;
}


############################################################################
#
# new
#
#    class/object method expecting no arguments and returning a reference to
#    a newly created Text::CSV object.
#
############################################################################

sub new ($;$) {
    my($proto, $attr) = @_;
    my($class) = ref($proto) || $proto;
    $attr ||= {};
    my($self) = {
	'_STATUS'      => undef,
	'_ERROR_INPUT' => undef,
	'_STRING'      => undef,
	'_FIELDS'      => undef,
	'quote_char'   => $attr->{'quote_char'}  || '"',
	'escape_char'  => $attr->{'escape_char'} || '"',
	'sep_char'     => $attr->{'sep_char'}    || ',',
	'binary'       => $attr->{'binary'}      || 0,
	'eol'          => exists($attr->{'eol'}) ? $attr->{'eol'} : ''
    };
    bless $self, $class;
    $self;
}


############################################################################
#
# status
#
#    object method returning the success or failure of the most recent
#    combine() or parse().  there are no side-effects.
############################################################################

sub status ($) {
  my $self = shift;
  return $self->{'_STATUS'};
}


############################################################################
#
# error_input
#
#    object method returning the first invalid argument to the most recent
#    combine() or parse().  there are no side-effects.
############################################################################

sub error_input ($) {
  my $self = shift;
  return $self->{'_ERROR_INPUT'};
}


############################################################################
#
# string
#
#    object method returning the result of the most recent combine() or the
#    input to the most recent parse(), whichever is more recent.  there are
#    no side-effects.
#
############################################################################

sub string ($) {
  my $self = shift;
  return $self->{'_STRING'};
}


############################################################################
# fields
#
#    object method returning the result of the most recent parse() or the
#    input to the most recent combine(), whichever is more recent.  there
#    are no side-effects.
#
############################################################################

sub fields ($) {
  my $self = shift;
  if (ref($self->{'_FIELDS'})) {
    return @{$self->{'_FIELDS'}};
  }
  return undef;
}


############################################################################
#
# combine
#
#    object method returning success or failure.  the given arguments are
#    combined into a single comma-separated value.  failure can be the
#    result of no arguments or an argument containing an invalid character.
#    side-effects include:
#      setting status()
#      setting fields()
#      setting string()
#      setting error_input()
#
############################################################################

sub combine ($@) {
  my $self = shift;
  my @part = @_;
  my($str) = '';
  my($ref) = \$str;
  $self->{'_FIELDS'} = \@part;
  $self->{'_ERROR_INPUT'} = undef;
  $self->{'_STATUS'} = 0;
  $self->{'_STATUS'} =
      (@part > 0)  &&  $self->Encode(\$str, \@part, 0, $self->{'eol'});
  $self->{'_STRING'} = $str;
  $self->{'_STATUS'};
}


############################################################################
#
# parse
#
#    object method returning success or failure.  the given argument is
#    expected to be a valid comma-separated value.  failure can be the
#    result of no arguments or an argument containing an invalid sequence
#    of characters. side-effects include:
#      setting status()
#      setting fields()
#      setting string()
#      setting error_input()
#
#############################################################################

sub parse ($$) {
  my($self, $str) = @_;
  my($fields) = [];
  $self->{'STRING'} = $self->{'ERROR_INPUT'} = $str;
  $self->{'_STATUS'} = 0;
  $self->{'_FIELDS'} = undef;
  if (defined($str)  &&  $self->Decode($str, $fields, 0)) {
      $self->{'_FIELDS'} = $fields;
      $self->{'_STATUS'} = 1;
  }
  return ($self->{'_STATUS'});
}


############################################################################
#
#    Name:    print (Instance method)
#
#    Purpose: Similar to combine, but the fields are encoded to an
#             IO stream or something similar. To be precise: An
#             object supporting a "print" method.
#
#    Inputs:  $self   - Instance
#             $io     - IO handle or similar object
#             $fields - Array ref to array of fields
#
#    Returns: TRUE for success, FALSE otherwise. In the latter case
#             you may look at $self->error_input() or check the IO
#             object for errors.
#
############################################################################

sub print ($$$) {
    my($self, $io, $fields) = @_;
    $self->{'_ERROR_INPUT'} = undef;
    $self->{'_STRING'} = undef;
    $self->{'_FIELDS'} = $fields;
    $self->{'_STATUS'} = $self->Encode($io, $fields, 1, $self->{'eol'});
}


############################################################################
#
#    Name:    getline (Instance method)
#
#    Purpose: Similar to parse, but the fields are decoded from an
#             IO stream or something similar. To be precise: An
#             object supporting a "getline" method.
#
#             Note that it may happen that multiple lines are read,
#             if the fields contain line feeds and we are in binary
#             mode. For example, MS Excel creates such files!
#
#    Inputs:  $self   - Instance
#             $io     - IO handle or similar object
#
#    Returns: Array ref of fields for success, undef otherwise.
#             In the latter case you may look at $self->error_input()
#             or check the IO object for errors.
#
############################################################################

sub getline ($$) {
    my($self, $io) = @_;
    my($fields) = [];
    $self->{'_ERROR_INPUT'} = undef;
    $self->{'_STRING'} = undef;
    $self->{'_FIELDS'} = $fields;
    if ($self->{'_STATUS'} = $self->Decode($io, $fields, 1)) {
	return $fields;
    }
    return undef;
}


bootstrap Text::CSV_XS $VERSION;

1;

__END__

=head1 NAME

Text::CSV_XS - comma-separated values manipulation routines

=head1 SYNOPSIS

 use Text::CSV_XS;

 $version = Text::CSV_XS->version();   # get the module version

 $csv = Text::CSV_XS->new();           # create a new object
 $csv = Text::CSV_XS->new(\%attr);     # create a new object

 $status = $csv->combine(@columns);    # combine columns into a string
 $line = $csv->string();               # get the combined string

 $status = $csv->parse($line);         # parse a CSV string into fields
 @columns = $csv->fields();            # get the parsed fields

 $status = $csv->status();             # get the most recent status
 $bad_argument = $csv->error_input();  # get the most recent bad argument

 $status = $csv->print($io, $columns); # Write an array of fields immediately
                                       # to a file $io

 $columns = $csv->getline($io);        # Read a line from file $io, parse it
                                       # and return an array ref of fields


=head1 DESCRIPTION

Text::CSV_XS provides facilities for the composition and decomposition of
comma-separated values.  An instance of the Text::CSV_XS class can combine
fields into a CSV string and parse a CSV string into fields.

=head1 FUNCTIONS

=over 4

=item version

 $version = Text::CSV_XS->version();

This function may be called as a class or an object method.  It returns the current
module version.

=item new

 $csv = Text::CSV_XS->new();
 $csv = Text::CSV_XS->new(\%attr);

This function may be called as a class or an object method.  It returns a
reference to a newly created Text::CSV_XS object. The optional argument
I<$attr> is a hash ref of attributes that modify the objects parsing
rules. Currently the following attributes are available:

=over 8

=item quote_char

The char used for quoting fields containing blanks, by default the
double quote character (C<">). A value of undef suppresses
quote chars. (For simple cases only).

=item eol

An end-of-line string to add to rows, usually C<undef> (nothing,
default), C<"\012"> (Line Feed) or C<"\015\012"> (Carriage Return,
Line Feed)

=item escape_char

The char used for escaping certain characters inside quoted fields,
by default the same character. (C<">)

=item sep_char

The char used for separating fields, by default a comme. (C<,>)

=item binary

If this attribute is TRUE, you may use binary characters in quoted fields,
including line feeds, carriage returns and NUL bytes. (The latter must
be escaped as C<"0>.) By default this feature is off.

=back

To sum it up,

 $csv = Text::CSV_XS->new();

is equivalent to

 $csv = Text::CSV_XS->new({
     'quote_char'  => '"',
     'escape_char' => '"',
     'sep_char'    => ',',
     'binary'      => 0
 });

=item combine

 $status = $csv->combine(@columns);

This object function constructs a CSV string from the arguments, returning
success or failure.  Failure can result from lack of arguments or an argument
containing an invalid character.  Upon success, C<string()> can be called to
retrieve the resultant CSV string.  Upon failure, the value returned by
C<string()> is undefined and C<error_input()> can be called to retrieve an
invalid argument.

=item print

 $status = $csv->print($io, $columns);

Similar to combine, but it expects an array ref as input (not an array!)
and the resulting string is not really created, but immediately written
to the I<$io> object, typically an IO handle or any other object that
offers a I<print> method. Note, this implies that the following is wrong:

 open(FILE, ">whatever");
 $status = $csv->print(\*FILE, $columns);

The glob C<\*FILE> is not an object, thus it doesn't have a print
method. The solution is to use an IO::File object or to hide the
glob behind an IO::Wrap object. See L<IO::File(3)> and L<IO::Wrap(3)>
for details.

For performance reasons the print method doesn't create a result string.
In particular the I<$csv->string()> method is meaningless after
executing this method.

=item string

 $line = $csv->string();

This object function returns the input to C<parse()> or the resultant CSV
string of C<combine()>, whichever was called more recently.

=item parse

 $status = $csv->parse($line);

This object function decomposes a CSV string into fields, returning
success or failure.  Failure can result from a lack of argument or the
given CSV string is improperly formatted.  Upon success, C<fields()> can
be called to retrieve the decomposed fields .  Upon failure, the value
returned by C<fields()> is undefined and C<error_input()> can be called
to retrieve the invalid argument.

=item getline

 $columns = $csv->getline($io);

This is the counterpart to print, like parse is the counterpart to
combine: It reads a row from the IO object $io using $io->getline()
and parses this row into an array ref. This array ref is returned
by the function or undef for failure.

=item fields

 @columns = $csv->fields();

This object function returns the input to C<combine()> or the resultant
decomposed fields of C<parse()>, whichever was called more recently.

=item status

 $status = $csv->status();

This object function returns success (or failure) of C<combine()> or
C<parse()>, whichever was called more recently.

=item error_input

 $bad_argument = $csv->error_input();

This object function returns the erroneous argument (if it exists) of
C<combine()> or C<parse()>, whichever was called more recently.

=back

=head1 EXAMPLE

  require Text::CSV_XS;

  my $csv = Text::CSV_XS->new;

  my $column = '';
  my $sample_input_string = '"I said, ""Hi!""",Yes,"",2.34,,"1.09"';
  if ($csv->parse($sample_input_string)) {
    my @field = $csv->fields;
    my $count = 0;
    for $column (@field) {
      print ++$count, " => ", $column, "\n";
    }
    print "\n";
  } else {
    my $err = $csv->error_input;
    print "parse() failed on argument: ", $err, "\n";
  }

  my @sample_input_fields = ('You said, "Hello!"',
			     5.67,
			     'Surely',
			     '',
			     '3.14159');
  if ($csv->combine(@sample_input_fields)) {
    my $string = $csv->string;
    print $string, "\n";
  } else {
    my $err = $csv->error_input;
    print "combine() failed on argument: ", $err, "\n";
  }

=head1 CAVEATS

This module is based upon a working definition of CSV format which may not be
the most general.

=over 4

=item 1 

Allowable characters within a CSV field include 0x09 (tab) and the inclusive
range of 0x20 (space) through 0x7E (tilde). In binary mode all characters
are accepted, at least in quoted fields:

=item 2

A field within CSV may be surrounded by double-quotes. (The quote char)

=item 3

A field within CSV must be surrounded by double-quotes to contain a comma.
(The separator char)

=item 4

A field within CSV must be surrounded by double-quotes to contain an embedded
double-quote, represented by a pair of consecutive double-quotes. In binary
mode you may additionally use the sequence C<"0> for representation of a
NUL byte.

=item 5

A CSV string may be terminated by 0x0A (line feed) or by 0x0D,0x0A
(carriage return, line feed).

=head1 AUTHOR

Alan Citterman F<E<lt>alan@mfgrtl.comE<gt>> wrote the original Perl
module.

Jochen Wiedmann F<E<lt>joe@ispsoft.deE<gt>> rewrote the encoding and
decoding in C by implementing a simple finite-state machine and added
the variable quote, escape and separator characters, the binary mode
and the print and getline methods.

=head1 SEE ALSO

L<perl(1)>, L<IO::File(3)>, L<IO::Wrap(3)>

=cut
