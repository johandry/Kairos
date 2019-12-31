package Controllers::Quick;

use strict;
use warnings;

use Dancer ':syntax';
use Dancer::Plugin::Database;
use Dancer::Plugin::FlashMessage;
use Controller qw(findAllOf findFirstOf intoDB);
use Controllers::Commands;
use Controllers::Schedules;

=pod

=cut

#                 0   1   2   3   4   5   6
my @WEEKDAYS = qw/Sun Mon Tue Wed Thu Fri Sat/;
#                 0 1   2   3   4   5   6   7   8   9   10  11  12
my @MONTHS   = qw/0 Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/;

sub insertResource ($$) {
  my $resource = shift;
  my $attr = shift;

  my $id = database->quick_lookup($attr->{table}, $resource, 'id');
  unless ( $id ) {
    database->quick_insert($attr->{table}, $resource);
    $id = database->quick_lookup($attr->{table}, $resource, 'id');
  }

  return { msgType => 'failure',  message => "Error Code: ".database->err.". Error Message: ".database->errstr } if database->err and database->err != 0;
  return { msgType => 'success',  id => $id }  
}

sub insertContainer ($$) {
  my $resource = shift;
  my $attr = shift;
  my $file_id;

  if ( $resource->{$attr->{file}} ) {
    $file_id = database->quick_lookup('Files', { name => $resource->{$attr->{file}}, type => $attr->{file} eq 'script' ? 'S' : 'F' }, 'id');
    unless ($file_id) {
      database->quick_insert('Files', { name => $resource->{$attr->{file}}, type => $attr->{file} eq 'script' ? 'S' : 'F' });
      $file_id = database->quick_lookup('Files', { name => $resource->{$attr->{file}}, type => $attr->{file} eq 'script' ? 'S' : 'F' }, 'id');
    }
  } else {
    return { msgType => 'failure',  message => ucfirst($attr->{file})." is not defined creating the ".ucfirst($resource->{resource})." $resource->{name}." };
  }

  my $container = { file_id => $file_id, machine_id => $resource->{$attr->{machine}}, credential_id => $resource->{$attr->{credential}} };
  $container->{name} = database->quick_lookup('Credentials', { id => $resource->{$attr->{credential}} }, 'username')."@".database->quick_lookup('Machines', { id => $resource->{$attr->{machine}} }, 'hostname').":".database->quick_lookup('Files', { id => $file_id }, 'name');
  return insertResource($container, { table => 'Containers' });
}

sub insertCommand ($) {
  my $resource = shift;
  my $result = insertContainer($resource, { file => 'script', machine => 'command_machine_id', credential => 'command_credential_id' });
  return $result if $result->{msgType} ne 'success';
  my $command = { name          => $resource->{name}." command",
                  container_id  => $result->{id},
                  parameters    => $resource->{parameters},
                  system        => 0,
                  type          => database->quick_lookup('CommandTypes', { name => 'In Action' }, 'id'),
                };
  return insertResource($command, { table => 'Commands' });         
}

sub insertFiletransfer ($) {
  my $resource = shift;

  my $result = insertContainer($resource, { file => 'source_file_name', machine => 'source_machine_id', credential => 'source_credential_id' });
  return $result if $result->{msgType} ne 'success';
  my $source_id = $result->{id};
  $result = insertContainer($resource, { file => 'target_file_name', machine => 'target_machine_id', credential => 'target_credential_id' });
  return $result if $result->{msgType} ne 'success';
  my $target_id = $result->{id};

  my $filetransfer = { source_id => $source_id, target_id => $target_id, protocol_id => $resource->{protocol_id} };
  $filetransfer->{name} = database->quick_lookup('Containers', { id => $source_id }, 'name').">".database->quick_lookup('Protocols', { id => $resource->{protocol_id} }, 'name').">".database->quick_lookup('Containers', { id => $target_id }, 'name');
  return insertResource($filetransfer, { table => 'Filetransfers' });
}

sub insertSchedule ($) {
  my $resource = shift;

  return { msgType => 'success',  id => $resource->{schedule_id} } if $resource->{schedule_id};

  my $schedule;
  $schedule->{week_days} = join ',', @{ $resource->{week_days} } if ref($resource->{week_days}) eq 'ARRAY';
  $schedule->{months}    = join ',', @{ $resource->{months}    } if ref($resource->{months})    eq 'ARRAY';
  ( $schedule->{minutes}, $schedule->{hours}, $schedule->{month_days} ) = map { $_ eq '*' ? undef : $_ } ( $resource->{minutes}, $resource->{hours}, $resource->{month_days} );
  $schedule->{name}        = Controllers::Schedules::short_name($schedule);
  $schedule->{description} = Controllers::Schedules::long_name($schedule);

  return insertResource($schedule, { table => 'Schedules' });
}

sub insertFilewatcher ($) {
  my $resource = shift;

  my $result = insertContainer($resource, { file => 'filewatcher_file_name', machine => 'filewatcher_machine_id', credential => 'filewatcher_credential_id' });
  return $result if $result->{msgType} ne 'success';
  my $container_id = $result->{id};

  my $schedule_id;
  if ($resource->{filewatcher_schedule_id}) {
    $schedule_id = $resource->{filewatcher_schedule_id};
  } else {
    $result = insertSchedule($resource);
    return $result if $result->{msgType} ne 'success';
    $schedule_id = $result->{id};
  }

  my $filewatcher = { schedule_id => $schedule_id, container_id => $container_id };
  $filewatcher->{name} = database->quick_lookup('Containers', { id => $container_id }, 'name')."#".database->quick_lookup('Schedules', { id => $schedule_id }, 'name');
  return insertResource($filewatcher, { table => 'Filewatchers' });
}

sub insertCondition ($) {
  my $resource = shift;
  my ($status_id, $job_id);

  if ( $resource->{status} ) {
    $status_id = Protocols::getStatusID($resource->{status}); # database->quick_lookup('Statuses', { name => $resource->{status} }, 'id');
    return { msgType => 'warning', message => "The Status ".$resource->{job_name}." was not not found creating the Filewatcher $resource->{name}." } unless $status_id;
  } else {
    return { msgType => 'failure',  message => "The status attribute is not defined creating the Filewatcher $resource->{name}." };
  }  

  if ( $resource->{job_name} ) {
    $job_id = database->quick_lookup('Jobs', { name => $resource->{job_name} }, 'id');
    return { msgType => 'warning', message => "The Job ".$resource->{job_name}." was not not found creating the Filewatcher $resource->{name}." } unless $job_id;
  } else {
    return { msgType => 'failure',  message => "The job_name attribute is not defined creating the Filewatcher $resource->{name}." };
  }

  my $schedule_id;
  if ($resource->{condition_schedule_id}) {
    $schedule_id = $resource->{condition_schedule_id};
  } else {
    my $result = insertSchedule($resource);
    return $result if $result->{msgType} ne 'success';
    $schedule_id = $result->{id};
  }

  my $condition = { status_id => $status_id, job_id => $job_id, schedule_id => $schedule_id };
  $condition->{name} = database->quick_lookup('Statuses', { id => $status_id }, 'shortname')."(".database->quick_lookup('Jobs', { id => $job_id }, 'name').")#".database->quick_lookup('Schedules', { id => $schedule_id }, 'name');
  return insertResource($condition, { table => 'Conditions' }); 
}

sub create_update ($) {
  my $params = shift;
  my $job_params;

  # Action Tab. Get action_id and action_type
  return { msgType => 'failure',  message => "Attribute job_type not defined creating the job ".$params->{name}."." } unless $params->{job_type}; 
  if ( $params->{job_type} eq 'f' ) {
    my $result = insertFiletransfer($params);  
    return $result if $result->{msgType} ne 'success';
    $job_params->{action_id} = $result->{id};
    $job_params->{action_type} = database->quick_lookup('Actions', { name => 'Filetransfer'}, 'id');
  } elsif ( $params->{job_type} eq 'c' ) {
    my $result = insertCommand($params);
    return $result if $result->{msgType} ne 'success';
    $job_params->{action_id} = $result->{id};
    $job_params->{action_type} = database->quick_lookup('Actions', { name => 'Command'}, 'id');
  }

  # Trigger Tab. Get trigger_id and trigger_type
  return { msgType => 'failure',  message => "Attribute trigger_type not defined creating the job ".$params->{name}."." } unless $params->{trigger_type}; 
  if ( $params->{trigger_type} eq 'f' ) {
    my $result = insertFilewatcher($params);  
    return $result if $result->{msgType} ne 'success';
    $job_params->{trigger_id} = $result->{id};
    $job_params->{trigger_type} = database->quick_lookup('Triggers', { name => 'Filewatcher'}, 'id');
  } elsif ( $params->{trigger_type} eq 's' ) {
    my $result = insertSchedule($params);
    return $result if $result->{msgType} ne 'success';
    $job_params->{trigger_id} = $result->{id};
    $job_params->{trigger_type} = database->quick_lookup('Triggers', { name => 'Schedule'}, 'id');
  } elsif ( $params->{trigger_type} eq 'c' ) {
    my $result = insertCondition($params);
    return $result if $result->{msgType} ne 'success';
    $job_params->{trigger_id} = $result->{id};
    $job_params->{trigger_type} = database->quick_lookup('Triggers', { name => 'Condition'}, 'id');
  }

  # Set defaults values
  $job_params->{contact_id}    = exists $params->{contact_id}    ? $params->{contact_id}    : 1; # if contact_id attribute is not found default is ypFTG Administrator
  $job_params->{active}        = exists $params->{active}        ? $params->{active}        : 1; # If active attribute is not found default is 1
  $job_params->{alarm_if_fail} = exists $params->{alarm_if_fail} ? $params->{alarm_if_fail} : 0; # If alarm_if_fail attribute is not found default is 0
  $job_params->{alarm_if_success} = exists $params->{alarm_if_success} ? $params->{alarm_if_success} : 0; # If alarm_if_success attribute is not found default is 0    

  # Main Tab.
  $job_params->{name} = $params->{name};
  my $group_id = database->quick_lookup('JobGroups', { name => $params->{group_name} }, 'id');
  unless ( $group_id ) {
    database->quick_insert('JobGroups', { name => $params->{group_name} });
    $group_id = database->quick_lookup('JobGroups', { name => $params->{group_name} }, 'id');
  }
  $job_params->{group_id} = $group_id;
  $job_params->{description} = $params->{description};

  my $post_actions   = $params->{post_actions};   $post_actions   = [ $post_actions ]   if ( defined $post_actions   and $post_actions   != 0 and ref( $post_actions )   ne 'ARRAY');
  my $pre_actions    = $params->{pre_actions};    $pre_actions    = [ $pre_actions ]    if ( defined $pre_actions    and $pre_actions    != 0 and ref( $pre_actions )    ne 'ARRAY');
  my $alarm_contacts = $params->{alarm_contacts}; $alarm_contacts = [ $alarm_contacts ] if ( defined $alarm_contacts and $alarm_contacts != 0 and ref( $alarm_contacts ) ne 'ARRAY');

  return { msgType => 'failure', message => 'Job could not be created.' } unless intoDB( 'Jobs', $job_params );

  my $job_id = database->quick_lookup('Jobs', $job_params, 'id');

  # Adding Pre Actions to the Job
  my $preActionId = database->quick_lookup('CommandTypes', { name => 'Pre Action' }, 'id');
  if ( defined $pre_actions and $pre_actions == 0 ) {
    database->quick_delete('JobsCommands', { job_id => $job_id, type => $preActionId });
  } else {
    my @allPreActionsOfThisJob = database->quick_select('JobsCommands', { job_id => $job_id, type => $preActionId });
    foreach my $preActionOfThisJob (@allPreActionsOfThisJob) {
      database->quick_delete('JobsCommands', { id => $preActionOfThisJob->{id} }) unless ( $preActionOfThisJob->{command_id} ~~ @$pre_actions );
    }
    my @pre_actionsOfThisJob = map { $_->{command_id} } @allPreActionsOfThisJob;
    foreach my $pre_action (@$pre_actions) {
      database->quick_insert('JobsCommands', { job_id => $job_id, command_id => $pre_action, type => $preActionId }) unless ( $pre_action ~~ @pre_actionsOfThisJob );
    }      
  }

  # Adding Post Actions to the Job
  my $postActionId = database->quick_lookup('CommandTypes', { name => 'Post Action' }, 'id');
  if ( defined $post_actions and $post_actions == 0 ) {
    database->quick_delete('JobsCommands', { job_id => $job_id, type => $postActionId });
  } else {    
    my @allPostActionsOfThisJob = database->quick_select('JobsCommands', { job_id => $job_id, type => $postActionId });  
    foreach my $postActionOfThisJob (@allPostActionsOfThisJob) {
      database->quick_delete('JobsCommands', { id => $postActionOfThisJob->{id} }) unless ( $postActionOfThisJob->{command_id} ~~ @$post_actions );
    }
    my @post_actionsOfThisJob = map { $_->{command_id} } @allPostActionsOfThisJob;
    foreach my $post_action (@$post_actions) {
      database->quick_insert('JobsCommands', { job_id => $job_id, command_id => $post_action, type => $postActionId }) unless ( $post_action ~~ @post_actionsOfThisJob );  
    }
  }

  # Adding Alarms to the Job
  if ( defined $alarm_contacts and $alarm_contacts == 0 ) {
    database->quick_delete('Alarms', { id => $job_id });
  } else {      
    my @allAlarmContactsOfThisJob = database->quick_select('Alarms', { job_id => $job_id });
    foreach my $alarmContactOfThisJob (@allAlarmContactsOfThisJob) {
      database->quick_delete('Alarms', { id => $alarmContactOfThisJob->{id} }) unless ( $alarmContactOfThisJob->{contact_id} ~~ @$alarm_contacts );
    }
    foreach my $alarm_contact (@$alarm_contacts) {
      database->quick_insert('Alarms', { job_id => $job_id, contact_id => $alarm_contact }) unless ( $alarm_contact ~~ @allAlarmContactsOfThisJob );  
    }
  }

  my $results;
  $results = { msgType => 'failure',  message => "Error Code: ".database->err.". Error Message: ".database->errstr } if database->err and database->err != 0;
  $results = { id => $job_id, msgType => 'success',  message => "The Job $params->{name} was successfuly cerated/updated." };
  flash $results->{msgType} => $results->{message};


  return $results;
}

# GET /jobs/new
# Render a form to create a new Team
sub new () {
  return { error => "You need to be Admin to create a new Job." } if ! Controller::amIAdmin;
  my $params = {};

  flash 'info' => "Before create a Job the required <b>Pre/Post Actions</b>, <b>Contacts</b>, <b>Credentials</b> and <b>Machines</b> must to exists.";

  # Main tab
  my @groups   = findAllOf('JobGroups');
  my @contacts = findAllOf('Contacts');

  # Action tab
  # my @filetransfers = findAllOf( 'Filetransfers' );
  my @protocols     = findAllOf('Protocols');
  # my @file_containers= Controllers::Commands::findAllContainersOfType('F');
  my @credentials   = findAllOf('Credentials');
  my @machines      = findAllOf('Machines');
  my @files         = database->quick_select('Files', { type => 'F' });

  # my @commands      = database->quick_select('Commands', 'type = '.database->quote($command_type->{in_action}).' OR type = '.database->quote($command_type->{any_action}) );
  my @scripts       = database->quick_select('Files', { type => 'S' });
  # my @script_containers = Controllers::Commands::findAllContainersOfType('S');

  # Triggers
  # my $filewatcher_type  = database->quick_select('Triggers', { name => 'Filewatcher' }, { columns => ['id', 'table_name'] });
  # my @filewatchers  = findAllOf($filewatcher_type->{table_name});
  my $schedule_type = database->quick_select('Triggers', { name => 'Schedule' }, { columns => ['id', 'table_name'] });
  my @schedules     = findAllOf($schedule_type->{table_name});
  my $schedule_id   = 1;
  my $default_schedule = database->quick_select('Schedules', { id => $schedule_id});
  my $schedule;
  my %days = map { $WEEKDAYS[$_] => 1 } (0..6);
  $schedule->{week_days} = \%days;
  my %months = map { $MONTHS[$_] => 1 } (0..12);
  $schedule->{months} = \%months;
  # my $condition_type= database->quick_select('Triggers', { name => 'Condition' }, { columns => ['id', 'table_name'] });
  # my @conditions    = findAllOf($condition_type->{table_name});
  my @statuses      = findAllOf('Statuses');
  my @jobs          = findAllOf('Jobs');

  # Pre/Post Actions
  my $command_type  = { any_action  => scalar database->quick_lookup('CommandTypes', { name => 'Any Action' }, 'id'),
                        pre_action  => scalar database->quick_lookup('CommandTypes', { name => 'Pre Action' }, 'id'),
                        post_action => scalar database->quick_lookup('CommandTypes', { name => 'Post Action' }, 'id'),
                        pre_post_action => scalar database->quick_lookup('CommandTypes', { name => 'Pre/Post Action' }, 'id'),
                      };  
  my @pre_actions   = database->quick_select('Commands', 'type = '.database->quote($command_type->{any_action}).' OR type = '.database->quote($command_type->{pre_post_action}).' OR type = '.database->quote($command_type->{pre_action}) );
  my @post_actions  = database->quick_select('Commands', 'type = '.database->quote($command_type->{any_action}).' OR type = '.database->quote($command_type->{pre_post_action}).' OR type = '.database->quote($command_type->{post_action}) );

  return { 
    groups        => \@groups, 
    contacts      => \@contacts,
    # filetransfers => \@filetransfers,
    protocols     => \@protocols,
    # file_containers=> \@file_containers,
    credentials   => \@credentials,
    machines      => \@machines,
    files         => \@files,
    command_type  => $command_type,
    # commands      => \@commands,
    scripts       => \@scripts,
    # script_containers=>\@script_containers,
    # filewatcher_type => $filewatcher_type,
    # filewatchers  => \@filewatchers,
    # schedule_type => $schedule_type,
    schedule_id   => $schedule_id,
    schedules     => \@schedules,
    default_schedule=> $default_schedule,
    schedule      => $schedule,
    # condition_type=> $condition_type,
    # conditions    => \@conditions,
    statuses      => \@statuses,
    jobs          => \@jobs,
    pre_actions   => \@pre_actions,
    post_actions  => \@post_actions,
  }
}

# POST /jobs
# Insert/Create a new Team with the data provided from the create form.
sub create ($) {
  my $params = shift;

  my $results = create_update( $params );  
  flash $results->{msgType} => $results->{message};
  return $results;
}

# GET /jobs/1/edit
# Render a Team data in a form to be updated.
sub edit ($) {
  my $params = shift;
  my $id = $params->{id};

  my $job = findFirstOf('Jobs', $id);
  return { job => $job }
}

# POST /jobs/1
# Update a Team with the data provided from the edit form.
# TODO: Should be used PUT insted of POST but it cannot be in a form. Need to find a way to send a PUT request.
sub update ($) {
  my $params = shift;

  if ( create_update( $params ) ) {
    flash success => "Job '".$params->{name}."' sucessfuly updated.";
  } else {
    flash error => "Something happen, the Job '".$params->{name}."' could not be updated.";
  }; 
}

# GET /jobs/1
# Render one Team
sub show ($) {
  my $params = shift;

  my $job = findFirstOf('Jobs', $params->{id});

  my @jobs = database->quick_select('Jobs', { group_id => $job->{id} });
  return { job => $job, jobs => \@jobs }
}

true;