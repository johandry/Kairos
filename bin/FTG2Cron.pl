#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Dancer ':script';
use Dancer::Plugin::Database;
use Controllers::Schedules;
use Controller qw(findFirstOf findAllOf getDBDate);

set log => 'error';

my $LOGING  = " >> \"$FindBin::Bin/../logs/cron.log\" 2>&1";
my $COMMAND = "export DANCER_ENVIRONMENT=production; \"$FindBin::Bin/execute.pl\"";
my $schedule_type_id = ${ database->quick_select('Triggers', { name => 'Schedule' }, { colums => ['id'] }) }{id}; 

sub crontabEntry ($$) {
  my $title    = shift;
  my $command  = shift;
  my @crontab  = ();
  push @crontab, '#'x80;
  push @crontab, "#  $title";
  push @crontab, '#'x80;
  push @crontab, $command;
  push @crontab, "";
  return @crontab;
}

# bySchedule is going to execute the Schedules when it is their time. Then, the schedule is going to execute the Jobs and Filewatchers
# This option will execute the Jobs and Filewatchers sequentially
sub bySchedule ($) {
  my $id = shift;

  my @crontab = ();
  my $command = "$COMMAND sch";

  if ( $id eq 'all' ) {
    my @schedules = findAllOf('Schedules');
    push @crontab, crontabEntry($_->{name}." execute the schedule with id ".$_->{id}, Controllers::Schedules::crontabFormat($_)."    $command $_->{id} $LOGING") foreach (@schedules);
  } else {
    my $schedule = findFirstOf('Schedules', $id);
    die "ERROR: The Schedule with ID $id was not found" unless $schedule;
    push @crontab, crontabEntry($schedule->{name}." execute the schedule with id $id", Controllers::Schedules::crontabFormat($schedule)."    $command $schedule->{id} $LOGING");
  }

  return @crontab;
}

sub scheduledResourceCrontabEntry ($) {
  my $schedule = shift;

  my @crontab = ();

  my @jobs = database->quick_select('Jobs', { trigger_type => $schedule_type_id, trigger_id => $schedule->{id} });
  push @crontab, crontabEntry($schedule->{name}." execute the Job $_->{name} with id $_->{id}", Controllers::Schedules::crontabFormat($schedule)."    $COMMAND job $_->{id} $LOGING") foreach (@jobs);
  my @filewatchers = database->quick_select('Filewatchers', { schedule_id => $schedule->{id} });
  push @crontab, crontabEntry($schedule->{name}." execute the Filewatcher $_->{name} with id $_->{id}", Controllers::Schedules::crontabFormat($schedule)."    $COMMAND fw $_->{id} $LOGING") foreach (@filewatchers);
  my @conditions = database->quick_select('Conditions', { schedule_id => $schedule->{id} });
  push @crontab, crontabEntry($schedule->{name}." execute Condition $_->{name} with id $_->{id}", Controllers::Schedules::crontabFormat($schedule)."    $COMMAND cond $_->{id} $LOGING") foreach (@conditions);

  return @crontab;
}

# byScheduledResources is going to execute the Jobs and Filewatchers when it is their time
# This option will execute the Jobs and Filewatchers in parallel.
sub byScheduledResources ($) {
  my $id = shift;

  my @crontab = ();

  if ( $id eq 'all' ) {
    my @schedules = findAllOf('Schedules');
    foreach my $schedule (@schedules) {
      push @crontab, scheduledResourceCrontabEntry($schedule);
    }
  } else {
    my $schedule = findFirstOf('Schedules', $id);
    die "ERROR: The Schedule with ID $id was not found" unless $schedule;
    push @crontab, scheduledResourceCrontabEntry($schedule);
  }

  return @crontab;
}

my $FTG2CronHelp = <<"EOHELP";
Execute:
  $0 OPTION all|id
Options: 
  schedules: Will setup cron entries to execute the Schedules when it is their time. Then, the schedule is going to execute the Jobs and Filewatchers. This option will execute the Jobs and Filewatchers sequentially.
  resources: Will setup cron entries to execute the Jobs, Filewatchers and Conditions when it is their time. This option will execute the Jobs, Filewatchers and Conditions in parallel. .
  all: Will replace the crontab with the execution of all the Schedules, Jobs or Filewatchers, depending of the option selected. This is the default option if the used option is not numeric.
  id : Will add the crontab entry with the execution of the Schedules, Jobs or Filewatchers, depending of the option selected, with this id.
EOHELP

die "ERROR: An Option with an ID or 'all' are required.".$FTG2CronHelp."$!" if $#ARGV < 1;

my $id      = ( $ARGV[1] =~ /\d+/ ) ? $ARGV[1] : 'all'  ;

my @crontab = ();
if ($ARGV[0] eq 'schedules') {
  @crontab = bySchedule($id);
} elsif ($ARGV[0] eq 'resources') {
  @crontab = byScheduledResources($id);
}

print "Replacing crontab with these entries:\n\n" if ($id eq 'all');
print "Adding to crontab this entry:\n\n" if ($id ne 'all');
print join "\n", @crontab;

open my $fh, "| crontab -" || die "can't open crontab: $!";
  if ($id ne 'all') {
    my $currentCrontab = qx(crontab -l | tail -n +4);
    print $fh $currentCrontab;
  } else {
    qx(crontab -l > "$FindBin::Bin/../db/crontab.`date +%Y%m%d%H%M`.bkp")
  }
  print $fh "\n";
  print $fh "$_\n" foreach @crontab;
close $fh;