#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Dancer ':script';
use Controllers::Jobs;
use Controllers::Schedules;
use Controllers::Filewatchers;
use Controller qw(findFirstOf);

my $executeHelp = <<"EOHELP";
Execute:
  $0 RESOURCE id
Where RESOURCE could be:
  job id : Execute the Job with identifier id.
  sch id : Execute the Scheduler with identifier id.
  fw id : Execute the Filewatcher with identifier id.
EOHELP

die "ERROR: A Resource and ID are required.".$executeHelp."$!" if $#ARGV < 1;

my $object = $ARGV[0];
my $id     = $ARGV[1];

set log => 'error';

my $results;

if ($object eq 'job') {
  $results = Controllers::Jobs::execute( {id => $id}, 1, 1 );

  # my $jobinstance = findFirstOf('JobInstances', $results->{jobinstance}->{id});
  # my $status      = findFirstOf('Statuses',     $jobinstance->{status_id}    );

  # print "Status:       ".$status->{name}."\n";
  # print "End on:       ".$jobinstance->{end_on}."\n";
  # print "Exit Code:    ".$jobinstance->{exit_code}."\n";
  # print "Results:      ".$jobinstance->{results}."\n";

} elsif ($object eq 'sch') {
  $results = Controllers::Schedules::execute( {id => $id}, 1 ); 
} elsif ($object eq 'fw') {
  $results = Controllers::Filewatchers::execute( {id => $id}, 1);
} else {
  die "ERROR: Resource $object unknown.".$executeHelp;
}