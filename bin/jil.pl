#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Dancer ':script';
use Dancer::Plugin::Database;
use Controller qw(findFirstOf findAllOf getDBDate);
use JIL;
use File::Basename qw/fileparse/;

use Data::Dumper;

set log => 'error';

my $file   = $ARGV[0];

die "No JIL or SQL file to load. Execute $0 file" if (! $file);

my ($name,$path,$suffix) = fileparse($file,".jil",".sql");

die "File to load is not a JIL or SQL file" if ( $suffix ne ".jil" && $suffix ne ".sql" );

my $appdir = config->{appdir};
my $fullpath = $appdir . "/tmp/" . $name . $suffix ;
die "File $file does not exists" if (! -e $fullpath);

if ( $suffix eq ".jil" ) {
  my $result = JIL::loadFile($fullpath);
  print "Status: ".ucfirst($result->{msgType})."\n";
  print "Messages: ".join "\n\t- ", split '<br>', $result->{message};
}