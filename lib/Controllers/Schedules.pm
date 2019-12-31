package Controllers::Schedules;

use strict;
use warnings;

use Dancer ':syntax';
use Dancer::Plugin::Database;
use Dancer::Plugin::FlashMessage;
use Controller qw(findAllOf findFirstOf intoDB);

use Controllers::Jobs;
use Controllers::Filewatchers;
use Controllers::Conditions;

=pod

=cut

#                 0   1   2   3   4   5   6
my @WEEKDAYS = qw/Sun Mon Tue Wed Thu Fri Sat/;
#                 0 1   2   3   4   5   6   7   8   9   10  11  12
my @MONTHS   = qw/0 Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/;

sub execute ($$) {
  my $params = shift;
  my $cli    = shift;
  my $id     = $params->{id};

  print "[".scalar localtime(time)."] - SCH - $id - STARTING - Starting Schedule with ID: $id. At ".__FILE__." line ".__LINE__.".\n" if $cli;

  my $schedule_type_id = ${ database->quick_select('Triggers', { name => 'Schedule' }, { colums => ['id'] }) }{id};
  my @jobs = database->quick_select('Jobs', { trigger_type => $schedule_type_id, trigger_id => $id });
  my @filewatchers = database->quick_select('Filewatchers', { schedule_id => $id });
  my @conditions = database->quick_select('Conditions', { schedule_id => $id });

  my @results = ();
  print "[".scalar localtime(time)."] - SCH - $id - RUNNING - Executing Jobs with Schedule ID: $id. At ".__FILE__." line ".__LINE__.".\n" if $cli;
  foreach my $job (@jobs) {
    # print "Active: '$job->{active}'\n";
    if ( $job->{active} == 1 ) {
      print "[".scalar localtime(time)."] - JOB - $job->{id} - STARTING - Executing Job $job->{name}. At ".__FILE__." line ".__LINE__.".\n" if $cli;
      push @results, Controllers::Jobs::execute( { id => $job->{id} }, 1, $cli);
    }
  }

  print "[".scalar localtime(time)."] - SCH - $id - RUNNING - Executing Filewatchers with Schedule ID: $id. At ".__FILE__." line ".__LINE__.".\n" if $cli;
  foreach my $filewatcher (@filewatchers) {
    # $now  = localtime(time);
    print "[".scalar localtime(time)."] - FW  - $filewatcher->{id} - STARTING - Executing Filewatcher $filewatcher->{name}. At ".__FILE__." line ".__LINE__.".\n" if $cli;
    my $fwResults = Controllers::Filewatchers::execute( { id => $filewatcher-> {id} }, $cli );
    push @results, @$fwResults;
  }

  # foreach my $condition (@conditions) {
  #   my $cResults = Controllers::Conditions::execute( { id => $condition-> {id} }, $cli );
  #   push @results, @$cResults;
  # }  
  print "[".scalar localtime(time)."] - SCH - $id - END - Ending Schedule with ID: $id. At ".__FILE__." line ".__LINE__.".\n" if $cli;

  return \@results;
}

sub crontabFormat ($) {
  my $schedule = shift;

  debug $schedule;

  return join ' ', map { defined $_ and $_ ne '' ? $_ : '*' } ($schedule->{minutes}, $schedule->{hours}, $schedule->{month_days}, $schedule->{months}, $schedule->{week_days});
}

sub check ($) {
  my $schedule = shift;

  return { msgType => 'success', message => 'It\'s time.' };
}

sub long_name ($) {
  my $params = shift;
  my $name = "";

  if ($params->{minutes} ne '') {
    if ($params->{minutes} =~ /^\*\/(.*)$/) {
      $name = "Every $1 minutes ";
    } else {
      $name = "At $params->{minutes} minutes ";
    }
  } else {
    $name = "Every minute ";
  }
  if ($params->{hours} ne '') {
    if ($params->{hours} =~ /^\*\/(.*)$/) {
      $name .= "every $1 hours ";
    } else {
      $name .= "at hours $params->{hours} ";
      if ($params->{hours} !~ /,/ and $params->{minutes}  ne '' and $params->{minutes} !~ /^\*\/(.*)$/ and $params->{minutes} !~ /,/) {
        $name = sprintf("At %02d:%02d", $params->{hours}, $params->{minutes});
      } elsif ($params->{hours} !~ /,/ and $params->{minutes} == '') {
        $name = sprintf("At %02d:00", $params->{hours});
      }
    }
  }  
  if ($params->{month_days} ne '') {
      $name .= "on days $params->{month_days} ";
  }  
  if (defined $params->{months} and $params->{months} ne '*') {
      $name .= "on ".join( ', ', map {$MONTHS[$_]} split(/,/, $params->{months}))." ";
  }  
  if (defined $params->{week_days} and $params->{week_days} ne '*') {
      $name .= "on ".join( ', ', map {$WEEKDAYS[$_]} split(/,/, $params->{week_days}));
  } 
  # $name = join '|', grep { defined $_ ? $_ : '*' } ($params->{minutes}, $params->{hours}, $params->{month_days}, $params->{months}, $params->{week_days});

  return $name;
}

sub short_name ($) {
  return crontabFormat($_[0]);
}

sub create_update ($) {
  return 0 if ! Controller::amIAdmin;
  my $params = shift;

  $params->{week_days} = join ',', @{ $params->{week_days} } if ref($params->{week_days}) eq 'ARRAY';
  $params->{week_days} = '*'                                 if $params->{week_days} and $params->{week_days} eq '0,1,2,3,4,5,6';
  $params->{week_days} = '*'                                 unless defined $params->{week_days};
  $params->{months}    = join ',', @{ $params->{months}    } if ref($params->{months})    eq 'ARRAY';
  $params->{months}    = '*'                                 if $params->{months}    and $params->{months}    eq '1,2,3,4,5,6,7,8,9,10,11,12';
  $params->{months}    = '*'                                 unless defined $params->{months};

  $params->{minutes}   = '*'                                 if not defined $params->{minutes}   or $params->{minutes}    eq '';
  $params->{hours}     = '*'                                 if not defined $params->{hours}     or $params->{hours}      eq '';
  $params->{month_days}= '*'                                 if not defined $params->{month_days}or $params->{month_days} eq '';

  $params->{name} = short_name($params);
  $params->{description} = long_name($params) unless $params->{description};

  return intoDB( 'Schedules', $params );
}

# GET /schedules
# List all the Schedules
sub index () {
  my @schedules = findAllOf('Schedules');
  return { schedules => \@schedules, pager => Controller::pager(scalar @schedules, param( 'per' ), param( 'cur' )) };
}

# GET /schedules/new
# Render a form to create a new Schedule
sub new () {
  return { error => "You need to be Admin to create a new Schedule." } if ! Controller::amIAdmin;
  my $schedule;
  my %days = map { $WEEKDAYS[$_] => 1 } (0..6);
  $schedule->{week_days} = \%days;
  my %months = map { $MONTHS[$_] => 1 } (0..12);
  $schedule->{months} = \%months;
  return { schedule => $schedule }
}

# POST /schedules
# Insert/Create a new Schedule with the data provided from the create form.
sub create ($) {
  return { error => "You need to be Admin to create this Schedule." } if ! Controller::amIAdmin;
  my $params = shift;
  if ( create_update( $params ) ) {
    flash success => "Schedule '".$params->{name}."' sucessfuly created/updated.";
  } else {
    flash error => "Something happen, the Schedule '".$params->{name}."' could not be created/upated.";
  }; 
}

# GET /schedules/1/edit
# Render a Schedule data in a form to be updated.
sub edit ($) {
  return { error => "You need to be Admin to edit this Schedule." } if ! Controller::amIAdmin;
  my $params = shift;
  my $id = $params->{id};

  my $schedule = findFirstOf('Schedules', $id);
  
  my %days;
  if ($schedule->{week_days} and $schedule->{week_days} ne '*') {
    %days = map { $WEEKDAYS[$_] => 1 } split(',',$schedule->{week_days});
  } else {
    %days = map { $WEEKDAYS[$_] => 1 } (0..6);
  }
  $schedule->{week_days} = \%days;

  my %months;
  if ($schedule->{months} and $schedule->{months} ne '*') {
    %months = map { $MONTHS[$_] => 1 } split(',',$schedule->{months});
  } else {
    %months = map { $MONTHS[$_] => 1 } (0..12);
  }
  $schedule->{months} = \%months;

  return { schedule => $schedule }
}

# POST /schedules/1
# Update a Schedule with the data provided from the edit form.
# TODO: Should be used PUT insted of POST but it cannot be in a form. Need to find a way to send a PUT request.
sub update ($) {
  return { error => "You need to be Admin to update this Schedule." } if ! Controller::amIAdmin;
  my $params = shift;
  if ( create_update( $params ) ) {
    flash success => "Schedule '".$params->{name}."' sucessfuly created/updated.";
  } else {
    flash error => "Something happen, the Schedule '".$params->{name}."' could not be created/upated.";
  }; 
}

# GET /schedules/1
# Render one Schedule
sub show ($) {
  my $params = shift;

  my $schedule = findFirstOf('Schedules', $params->{id});

  if ($schedule->{minutes}) {
    if ($schedule->{minutes} =~ /^\*\/(.*)$/) {
      $schedule->{Dminutes} = "Every $1 minutes";
    } else {
      $schedule->{Dminutes} = "Each $schedule->{minutes} minutes";
    }
  } else {
    $schedule->{Dminutes} = "Every minute";
  }
  if ($schedule->{hours}) {
    if ($schedule->{hours} =~ /^\*\/(.*)$/) {
      $schedule->{Dhours} = "Every $1 hours";
    } else {
      $schedule->{Dhours} = "Each $schedule->{hours} hours";
    }
  }  else {
    $schedule->{Dhours} = "Every hour";
  }
  if ($schedule->{month_days}) {
      $schedule->{Dmonth_days} = "Each $schedule->{month_days} days";
  }  else {
    $schedule->{Dmonth_days} = "Every day";
  }
  if ($schedule->{months} and $schedule->{months} ne '*') {
      $schedule->{Dmonths} = "Each ".join( ', ', map {$MONTHS[$_]} split(/,/, $schedule->{months}));
  }  else {
    $schedule->{Dmonths} = "Every month";
  }  
  if ($schedule->{week_days} and $schedule->{week_days} ne '*') {
      $schedule->{Dweek_days} = "Each ".join( ', ', map {$WEEKDAYS[$_]} split(/,/, $schedule->{week_days}));
  }  else {
    $schedule->{Dweek_days} = "Every day of the week";
  }   

  my $schedule_type_id = ${ database->quick_select('Triggers', { name => 'Schedule' }, { colums => ['id'] }) }{id};
  my @jobs = database->quick_select('Jobs', { trigger_type => $schedule_type_id, trigger_id => $schedule->{id} });
  my @filewatchers = database->quick_select('Filewatchers', { schedule_id => $schedule->{id} });
  my @conditions = database->quick_select('Conditions', { schedule_id => $schedule->{id} });
  my $crontab = crontabFormat($schedule);

  return { schedule =>$schedule, jobs => \@jobs, filewatchers => \@filewatchers, conditions => \@conditions, crontab => $crontab }  
}

true;