# -*- perl -*-
require 5.004;
use strict;

require ExtUtils::MakeMaker;

my($def) = '';
if ($ENV{'USER'} eq 'joe'  &&  $ENV{'HOSTNAME'} eq 'laptop.ispsoft.de') {
    $def .= ' -Wall -Wno-unused';
}

ExtUtils::MakeMaker::WriteMakefile(
    'NAME'	   => 'Text::CSV_XS',
    'VERSION_FROM' => 'CSV_XS.pm', # finds $VERSION
    'dist'         => { 'SUFFIX'       => ".gz",
                         'DIST_DEFAULT' => 'all tardist',
                         'COMPRESS'     => "gzip -9f" },
    'DEFINE'       => $def
);
