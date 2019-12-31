package Searches;

use strict;
use warnings;

use Dancer ':syntax';
use Dancer::Plugin::Database;

use Controller qw(getDBToday);
use Time::Local;

my $TABLES = {
  Teams         => [ 'name', 'email', 'description' ],
  Contacts      => [ 'corpid', 'firstname', 'lastname', 'email' ],
  Credentials   => [ 'username', 'description' ],
  Datacenters   => [ 'name', 'address' ],
  Machines      => [ 'hostname', 'domainname', 'ip', 'description' ],
  Files         => [ 'name', 'description' ],
  Containers    => [ 'name', 'description' ],
  # Protocols     => [ 'name', 'description' ], # Internal use only
  Filetransfers => [ 'name', 'description' ],
  Schedules     => [ 'name', 'description' ],
  Filewatchers  => [ 'name', 'description' ],
  Conditions    => [ 'name', 'description' ],
  # Triggers      => [ 'name', 'table_name', 'description' ], # Internal use only
  # Alarms        => [],         # Have not text fields just references
  # CommandTypes  => [ 'name' ], # Internal use only
  Commands      => [ 'name', 'parameters', 'description' ],
  # JobsCommands  => [],         # Have not text fields just references
  # Actions       => [ 'name', 'table_name', 'description' ], # Internal use only
  Jobs          => [ 'name' ],
  JobGroups     => [ 'name', 'description' ],
  # Statuses      => [],         # Internal use only
  JobInstances  => [ 'start_on', 'end_on', 'results' ],
  Roles         => [ 'name' ],
  Users         => [ 'username' ],
};

sub searchTable ($$) {
  my $table = shift;
  my $query = shift;

  my @columns = ('id', @{ $TABLES->{$table} });
  my $where = join( 'OR', map { " $_ LIKE ".database->quote("%$query%")." " } @{ $TABLES->{$table} });
  my @results = ();
  if ($table eq 'JobInstances') {
    push @columns, ('job_id', 'status_id');
    my @groups = database->quick_select('JobGroups', "name LIKE ".database->quote("%$query%")." OR description LIKE ".database->quote("%$query%"), { columns => ['id'] });
    my $where_groups = '';
    if (@groups) {
      if (scalar(@groups) > 1) {
        $where_groups = " OR group_id IN (".join(',', map { $_->{id} } @groups).")";
      } else {
        $where_groups = " OR group_id=".$groups[0]->{id};
      }
    }
    my @jobs = database->quick_select('Jobs', "name LIKE ".database->quote("%$query%").$where_groups, { columns => ['id'] });
    my $where_jobs = '';
    if (@jobs) {
      if (scalar(@jobs) > 1) {
        $where_jobs = " OR job_id IN (".join(',', map { $_->{id} } @jobs).")";
      } else {
        $where_jobs = " OR job_id=".$jobs[0]->{id};
      }
    }    
    my @statuses = database->quick_select('Statuses', "name LIKE ".database->quote("%$query%")." OR description LIKE ".database->quote("%$query%"), { columns => ['id'] });
    my $where_status = '';
    if (@statuses) {
      if (scalar(@statuses) > 1) {
        $where_status = " OR status_id IN (".join(',', map { $_->{id} } @statuses).")";
      } else {
        $where_status = " OR status_id=".$statuses[0]->{id};
      }
    }    

    my $LAST_HOURS = 36;
    my ($sec1, $min1, $hour1, $mday1, $mon1, $year1) = localtime();
    my $time_lastSearchHours = timelocal($sec1, $min1, $hour1, $mday1, $mon1, $year1) - $LAST_HOURS*60*60;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time_lastSearchHours);
    my $lastSearchHours = sprintf("%4d-%02d-%02d %02d:%02d:%02d",$year+1900,$mon+1,$mday,$hour,$min,$sec);

    $where = "start_on >= ".database->quote("$lastSearchHours")." AND (".$where." $where_jobs $where_status)";
    @results = database->quick_select( 'JobInstances', $where, { columns => \@columns, order_by => { desc => 'id' } } );
    foreach my $jobinstance (@results) {
      my $job = database->quick_select('Jobs', { id => $jobinstance->{job_id} }, { columns => ['name', 'group_id']} );
      $jobinstance->{job_name} = $job->{name};
      $jobinstance->{group} = database->quick_lookup('JobGroups', { id => $job->{group_id} }, 'name');
      $jobinstance->{status} = database->quick_lookup('Statuses', { id => $jobinstance->{status_id} }, 'name');
    }
  } else {
    @results = database->quick_select( $table, $where, { columns => \@columns } );
  }
  # debug "SELECT ".join(', ', @columns)." FROM $table WHERE $where";
  
  return @results;
}

sub basicSearch ($) {
  my $query = shift;

  return undef unless $query;

  my $results = { total => 0 };
  foreach ( keys %{ $TABLES } ) {
    my @found = searchTable($_, $query);
    $results->{total} += scalar(@found);
    $results->{lc $_} = \@found;
    # $results->{lc $_}->{pager} = Controller::pager(scalar @found, param( 'per' ), param( 'cur' ));
  }

  return $results;
}


true;