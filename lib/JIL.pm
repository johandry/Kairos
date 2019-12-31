package JIL;

use strict;
use warnings;

use Dancer ':syntax';
use Dancer::Plugin::Database;

use Controllers::Schedules;

use Data::Dumper;

our $VERSION = '0.1';

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
  my ($file_id, $machine_id, $credential_id);

  if ( $resource->{$attr->{file}} ) {
    $file_id = database->quick_lookup('Files', { name => $resource->{$attr->{file}}, type => $attr->{file} eq 'script' ? 'S' : 'F' }, 'id');
    unless ($file_id) {
      database->quick_insert('Files', { name => $resource->{$attr->{file}}, type => $attr->{file} eq 'script' ? 'S' : 'F' });
      $file_id = database->quick_lookup('Files', { name => $resource->{$attr->{file}}, type => $attr->{file} eq 'script' ? 'S' : 'F' }, 'id');
    }
  } else {
    return { msgType => 'failure',  message => ucfirst($attr->{file})." is not defined creating the ".ucfirst($resource->{resource})." $resource->{name}." };
  }

  if ( $resource->{$attr->{machine}} ) {
    $machine_id = database->quick_lookup('Machines', { hostname => $resource->{$attr->{machine}} }, 'id');
    return { msgType => 'warning', message => ucfirst($attr->{machine})." ".$resource->{$attr->{machine}}." was not not found creating the ".ucfirst($resource->{resource})." $resource->{name}." } unless $machine_id;
  } else {
    return { msgType => 'failure',  message => ucfirst($attr->{machine})." is not defined creating the ".ucfirst($resource->{resource})." $resource->{name}." };
  }

  if ( $resource->{$attr->{credential}} ) {
    $credential_id = database->quick_lookup('Credentials', { username => $resource->{$attr->{credential}} }, 'id');
    return { msgType => 'warning', message => ucfirst($attr->{credential})." ".$resource->{$attr->{credential}}." was not not found creating the ".ucfirst($resource->{resource})." $resource->{name}." } unless $credential_id;
  } else {
    return { msgType => 'failure',  message => ucfirst($attr->{credential})." is not defined creating the ".ucfirst($resource->{resource})." $resource->{name}." };
  }  

  my $container = { file_id => $file_id, machine_id => $machine_id, credential_id => $credential_id };
  $container->{name} = database->quick_lookup('Credentials', { id => $credential_id }, 'username')."@".database->quick_lookup('Machines', { id => $machine_id }, 'hostname').":".database->quick_lookup('Files', { id => $file_id }, 'name');
  return insertResource($container, { table => 'Containers' });
}

sub insertFiletransfer ($) {
  my $resource = shift;

  my $result = insertContainer($resource, { file => 'source_file', machine => 'source_machine', credential => 'source_credential' });
  return $result if $result->{msgType} ne 'success';
  my $source_id = $result->{id};
  $result = insertContainer($resource, { file => 'target_file', machine => 'target_machine', credential => 'target_credential' });
  return $result if $result->{msgType} ne 'success';
  my $target_id = $result->{id};

  my $protocol_id = database->quick_lookup('Protocols', { name => uc($resource->{protocol}) }, 'id');
  return { msgType => 'failure', message => "Protocol ".$resource->{protocol}." was not not found creating the ".ucfirst($resource->{resource})." $resource->{name}." } unless $protocol_id;

  my $filetransfer = { source_id => $source_id, target_id => $target_id, protocol_id => $protocol_id };
  $filetransfer->{name} = database->quick_lookup('Containers', { id => $source_id }, 'name').">".uc($resource->{protocol}).">".database->quick_lookup('Containers', { id => $target_id }, 'name');
  return insertResource($filetransfer, { table => 'Filetransfers' });
}

sub insertSchedule ($) {
  my $resource = shift;

  my $schedule;
  ( $schedule->{minutes}, $schedule->{hours}, $schedule->{month_days}, $schedule->{months}, $schedule->{week_days} ) = map { $_ eq '*' ? undef : $_ } split ' ', $resource->{schedule};
  $schedule->{name}        = Controllers::Schedules::short_name($schedule);
  $schedule->{description} = Controllers::Schedules::long_name($schedule);

  return insertResource($schedule, { table => 'Schedules' });
}

sub insertFilewatcher ($) {
  my $resource = shift;

  my $result = insertContainer($resource, { file => 'file_to_watch', machine => 'machine', credential => 'credential' });
  return $result if $result->{msgType} ne 'success';
  my $container_id = $result->{id};

  $result = insertSchedule($resource);
  return $result if $result->{msgType} ne 'success';
  my $schedule_id = $result->{id};

  my $filewatcher = { schedule_id => $schedule_id, container_id => $container_id };
  $filewatcher->{name} = database->quick_lookup('Containers', { id => $container_id }, 'name')."#".database->quick_lookup('Schedules', { id => $schedule_id }, 'name');
  return insertResource($filewatcher, { table => 'Filewatchers' });
}

sub insertCondition ($) {
  my $resource = shift;
  my ($status_id, $job_id);

  if ( $resource->{status} ) {
    $status_id = database->quick_lookup('Statuses', { name => $resource->{status} }, 'id');
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

  my $result = insertSchedule($resource);
  return $result if $result->{msgType} ne 'success';
  my $schedule_id = $result->{id};

  my $condition = { status_id => $status_id, job_id => $job_id, schedule_id => $schedule_id };
  $condition->{name} = database->quick_lookup('Statuses', { id => $status_id }, 'shortname')."(".database->quick_lookup('Jobs', { id => $job_id }, 'name').")#".database->quick_lookup('Schedules', { id => $schedule_id }, 'name');
  return insertResource($condition, { table => 'Conditions' }); 
}

sub addAction ($) {
  my $attr = shift;

  # If this is an update, delete all the post or pre actions if any defined. If no action is defined keep them
  database->quick_delete('JobsCommands', { job_id => $attr->{job_id}, type => $attr->{type} })  if $attr->{action} eq 'update';

  my @not_found = ();
  foreach my $action (map { s/^\s+|\s+$//g } split ',', $attr->{actions}) {
    my $action_id = database->quick_lookup('Commands', { name => $action }, 'id');
    if ($action_id) {
      database->quick_insert('JobsCommands', { job_id => $attr->{job_id}, action_id => $action_id, type => $attr->{attr}} );
    } else {
      push @not_found, $action; 
    }
  }
  return { msgType => 'failure',  message => "Error Code: ".database->err.". Error Message: ".database->errstr } if database->err and database->err != 0;
  return { msgType => 'warning',  message => "The following actions '".join(', ', @not_found)."' where not not found creating the Job $attr->{job_name}." } unless scalar(@not_found);
  return { msgType => 'success',  message => "The following actions '$attr->{actions}' where added to the Job $attr->{job_name}." };
}

sub addActions ($$) {
  my $resource = shift;
  my $attr = shift;
  my $return_result = { msgType => 'success', message => "" };
  my $result;

  $attr->{action}  = $resource->{action};
  $attr->{job_name}= $resource->{name};

  if ($resource->{pre_action}) {
    $attr->{type}   = database->quick_lookup('JobsCommands', { name => 'Pre Action' },  'id');
    $attr->{actions}= $resource->{pre_action};
    $result = addAction($attr);
    $return_result->{msgType} = $result->{msgType};
    $return_result->{message} = $result->{message};
  }

  if ($resource->{post_action}) {
    $attr->{type}   = database->quick_lookup('JobsCommands', { name => 'Post Action' },  'id');
    $attr->{actions}= $resource->{post_action};
    $result = addAction($attr);
    $return_result->{msgType} = 'warning' if ( $result->{msgType} eq 'warning' and $return_result->{msgType} ne 'failure' );
    $return_result->{msgType} = 'failure' if ( $result->{msgType} eq 'failure' );
    $return_result->{message} .= '<br>'.$result->{message};
  }

  return $return_result;
} 

sub addAlarms ($$) {
  my $resource = shift;
  my $attr = shift;

  # If this is an update, delete all the alarms if any defined. If no alarm is defined keep them
  database->quick_delete('Alarms', { job_id => $attr->{job_id} }) if $resource->{action} eq 'update';

  my @not_found = ();
  foreach my $contact (map { s/^\s+|\s+$//g } split ',', $resource->{alarm_to}) {
    my $contact_id = database->quick_lookup('Contacts', { corpid => $contact }, 'id');
    if ($contact_id) {
      database->quick_insert('Alarms', { job_id => $attr->{job_id}, contact_id => $contact_id} );
    } else {
      push @not_found, $contact;
    }
  }
  return { msgType => 'failure',  message => "Error Code: ".database->err.". Error Message: ".database->errstr } if database->err and database->err != 0;
  return { msgType => 'warning',  message => "The following contacts '".join(', ', @not_found)."' where not not found creating the alarms of the Job $attr->{job_name}." } unless scalar(@not_found);
  return { msgType => 'success',  message => "The following contacts '$resource->{alarm_to}' where added to the alarms of the Job $resource->{name}." };
} 

sub insert_updateResource ($$) {
  my $jilAttr = shift;
  my $attr = shift;

  my $resource = { $attr->{key} => $jilAttr->{name} };
  if ( $attr->{foreingkeys} ) {
    foreach my $foreingkey (@{ $attr->{foreingkeys} }) {
      if ( $jilAttr->{$foreingkey->{jilattr}} ) {
        my $fk_id = database->quick_lookup($foreingkey->{table}, { $foreingkey->{key} => $jilAttr->{$foreingkey->{jilattr}} }, 'id');
        return { msgType => 'warning', message => $jilAttr->{$foreingkey->{jilattr}}." was not not found in ".$foreingkey->{table} } unless $fk_id;
        $resource->{$foreingkey->{fk_id}} = $fk_id;
      }
    }
  }
  map { $resource->{$_} = $jilAttr->{$_} if $jilAttr->{$_} } @{$attr->{map}};

  my $id = database->quick_lookup( $attr->{table}, { $attr->{key} => $jilAttr->{name} }, 'id');                  
  if ( $jilAttr->{actionname} eq 'insert' ) {
    return { msgType => 'warning', message => ucfirst($jilAttr->{resource})." $jilAttr->{name} exists with id $id and cannot be inserted." } if $id;
    database->quick_insert( $attr->{table}, $resource);
  } elsif ( $jilAttr->{actionname} eq 'update' ) {
    return { msgType => 'warning', message => ucfirst($jilAttr->{resource})." $jilAttr->{name} does not exists and cannot be updated." } unless $id;
    database->quick_update( $attr->{table}, $resource, { id => $id });
  }
  return { msgType => 'failure',  message => "Error Code: ".database->err.". Error Message: ".database->errstr } if database->err and database->err != 0;
  return { msgType => 'success',  message => "The ".ucfirst($jilAttr->{resource})." $jilAttr->{name} was $jilAttr->{actionname}ed." }
}

sub insert_update ($) {
  return insert_updateResource( $_[0], { 
    table => 'Machines', 
    key => 'hostname', 
    map => ['domainname', 'ip', 'description'], 
    foreingkeys => [
      { jilattr => 'datacenter', table => 'Datacenters', key => 'name', fk_id => 'dc_id', }
    ] 
  }) if $_[0]->{resource} eq 'machine';

  return insert_updateResource( $_[0], { 
    table => 'Teams', 
    key => 'name', 
    map => ['email', 'description'], 
  }) if $_[0]->{resource} eq 'team';

  return insert_updateResource( $_[0], { 
    table => 'Contacts', 
    key => 'corpid', 
    map => ['firstname', 'lastname', 'email', 'description'], 
    foreingkeys => [
      { jilattr => 'team', table => 'Teams', key => 'name', fk_id => 'team_id', }
    ] 
  }) if $_[0]->{resource} eq 'contact';

  if ( $_[0]->{resource} eq 'action' ) {
    my $result = insertContainer($_[0], { file => 'script', machine => 'machine', credential => 'credential' });
    return $result if $result->{msgType} ne 'success';
    $_[0]->{container_id} = $result->{id};
    return { msgType => 'failure',  message => "Attribute action_type not defined creating the action ".$_[0]->{name}."." } unless $_[0]->{action_type};
    $_[0]->{action_type} =~ s/p/P/g;   # pre to Pre, post to Post and pre/post to Pre/Post
    $_[0]->{action_type} .= " Action"; # Pre Action, Post Action and Pre/Post Action
    return insert_updateResource( $_[0], { 
      table => 'Commands', 
      key => 'name', 
      map => ['parameter', 'system', 'description', 'container_id'], 
      foreingkeys => [
        { jilattr => 'action_type', table => 'CommandTypes', key => 'name', fk_id => 'type', }
      ] 
    });
  }

  if ( $_[0]->{resource} eq 'job' ) {
    # Get action_id and action_type
    return { msgType => 'failure',  message => "Attribute job_type not defined creating the job ".$_[0]->{name}."." } unless $_[0]->{job_type}; 
    if ( $_[0]->{job_type} eq 'f' ) {
      my $result = insertFiletransfer($_[0]);  
      return $result if $result->{msgType} ne 'success';
      $_[0]->{action_id} = $result->{id};
      $_[0]->{action_type} = database->quick_lookup('Actions', { name => 'Filetransfer'}, 'id');
    } elsif ( $_[0]->{job_type} eq 'c' ) {
      my $result = insertContainer($_[0], { file => 'script', machine => 'machine', credential => 'credential' });
      return $result if $result->{msgType} ne 'success';
      $_[0]->{action_id} = $result->{id};
      $_[0]->{action_type} = database->quick_lookup('Actions', { name => 'Command'}, 'id');
    }

    # Get trigger_id and trigger_type
    return { msgType => 'failure',  message => "Attribute trigger_type not defined creating the job ".$_[0]->{name}."." } unless $_[0]->{trigger_type}; 
    if ( $_[0]->{trigger_type} eq 'f' ) {
      my $result = insertFilewatcher($_[0]);  
      return $result if $result->{msgType} ne 'success';
      $_[0]->{trigger_id} = $result->{id};
      $_[0]->{trigger_type} = database->quick_lookup('Triggers', { name => 'Filewatcher'}, 'id');
    } elsif ( $_[0]->{trigger_type} eq 's' ) {
      my $result = insertSchedule($_[0]);
      return $result if $result->{msgType} ne 'success';
      $_[0]->{trigger_id} = $result->{id};
      $_[0]->{trigger_type} = database->quick_lookup('Triggers', { name => 'Schedule'}, 'id');
    } elsif ( $_[0]->{trigger_type} eq 'c' ) {
      my $result = insertCondition($_[0]);
      return $result if $result->{msgType} ne 'success';
      $_[0]->{trigger_id} = $result->{id};
      $_[0]->{trigger_type} = database->quick_lookup('Triggers', { name => 'Condition'}, 'id');
    }

    # Set defaults values
    $_[0]->{contact_id}    = $_[0]->{owner}         ? $_[0]->{owner}         : 'ypFTG'; # contact_id is owner but if owner attribute is not found default is ypFTG Administrator
    $_[0]->{active}        = $_[0]->{active}        ? $_[0]->{active}        : 1;       # If active attribute is not found default is 1
    $_[0]->{alarm_if_fail} = $_[0]->{alarm_if_fail} ? $_[0]->{alarm_if_fail} : 0;       # If alarm_if_fail attribute is not found default is 0
    $_[0]->{alarm_to}      = $_[0]->{alarm_to}      ? $_[0]->{alarm_to}      : $_[0]->{contact_id}; # If alarm_to attribute is not found default is owner

    my $contact_id = database->quick_lookup('Contacts', { corpid => $_[0]->{contact_id} }, 'id');
    return { msgType => 'warning', message => "The Owner ".$_[0]->{contact_id}." was not not found creating the Job ".$_[0]->{name}."." } unless $contact_id;
    $_[0]->{contact_id} = $contact_id;

    my $last_result =  insert_updateResource( $_[0], { 
      table => 'Jobs', 
      key => 'name', 
      map => [ 'action_id', 'action_type', 'trigger_id', 'trigger_type', 'contact_id', 'alarm_if_fail', 'active', 'description'], 
    });
    return $last_result if $last_result->{msgType} ne 'success';
    my $job_id = database->quick_lookup('Jobs', { name => $_[0]->{name} }, 'id');

    # Add the pre_actions, post_actions to the table JobsCommands
    my $return_result = addActions( $_[0], { job_id => $job_id }) if $_[0]->{pre_action} or $_[0]->{post_action};

    # Add the alarm_to to the table Alarms
    my $result = addAlarms( $_[0], { job_id => $job_id }) if $_[0]->{alarm_to};

    $return_result->{msgType} = 'warning' if ( $result->{msgType} eq 'warning' and $return_result->{msgType} ne 'failure' );
    $return_result->{msgType} = 'failure' if ( $result->{msgType} eq 'failure' );
    $return_result->{message} .= '<br>'.$result->{message};

    $return_result->{msgType} = 'warning' if ( $last_result->{msgType} eq 'warning' and $return_result->{msgType} ne 'failure' );
    $return_result->{msgType} = 'failure' if ( $last_result->{msgType} eq 'failure' );
    $return_result->{message} .= '<br>'.$last_result->{message};

    return $return_result;
  }  
}

sub deleteResource ($$) {
  my $resource = shift;
  my $attr = shift;

  my $result = {};
  my $id = database->quick_lookup( $attr->{table}, { $attr->{key} => $resource->{name} }, 'id' ); 
  return { msgType => 'warning', message => ucfirst($resource->{resource})." $resource->{name} does not exists and cannot be deleted." } unless $id;
  
  if ($attr->{usedby}) {
    foreach my $external_resource (@{$attr->{usedby}}) {
      my $count = database->quick_count( $external_resource->{table}, { $external_resource->{fk_id} => $id } );
      my $resource_using_it = $external_resource->{resource_using_it} ? $external_resource->{resource_using_it} : $external_resource->{table};
      return { msgType => 'warning', message => ucfirst($resource->{resource})." $resource->{name} was not deleted because is used by $count $resource_using_it." } if $count;
    }
  }

  database->quick_delete( $attr->{table}, { id => $id } );
  if ( database->err ) {
    $result = { msgType => 'warning', message => "The ".$resource->{resource}." ".$resource->{name}." was not deleted. ".database->errstr };
  } else {
    $result = { msgType => 'success', message => "The ".$resource->{resource}." ".$resource->{name}." was deleted." };
  }
  return $result;
}

sub delete ($) {
  return deleteResource($_[0], { 
    table => 'Machines', 
    key => 'hostname', 
    usedby => [
      { table => 'Containers', fk_id => 'machine_id', }
    ],
  }) if ( $_[0]->{resource} eq 'machine' );

  return deleteResource($_[0], { 
    table => 'Teams',    
    key => 'name', 
    usedby => [
      { table => 'Contacts', fk_id => 'team_id', }
    ],
  }) if ( $_[0]->{resource} eq 'team' );

  return deleteResource($_[0], { 
    table => 'Contacts', 
    key => 'corpid', 
    usedby => [
      { table => 'Credentials', fk_id => 'contact_id', },
      { table => 'Jobs',        fk_id => 'contact_id', }
    ],
  }) if ( $_[0]->{resource} eq 'contact' );

  return deleteResource($_[0], { 
    table => 'Commands', 
    key => 'name', 
    usedby => [
      { table => 'JobsCommands', fk_id => 'command_id', resource_using_it => 'Jobs'}
    ],
  }) if ( $_[0]->{resource} eq 'action' );

  if ( $_[0]->{resource} eq 'job' ) {
    my $id = database->quick_lookup( 'Jobs', { name => $_[0]->{name} }, 'id' ); 
    return { msgType => 'warning', message => "Job $_[0]->{name} does not exists and cannot be deleted." } unless $id;
    database->quick_delete('JobsCommands', { job_id => $id });
    return { msgType => 'failure',  message => "Error Code: ".database->err.". Error Message: ".database->errstr } if database->err and database->err != 0;
    database->quick_delete('Alarms',       { job_id => $id });
    return { msgType => 'failure',  message => "Error Code: ".database->err.". Error Message: ".database->errstr } if database->err and database->err != 0;
    return deleteResource($_[0], { 
      table => 'Jobs', 
      key => 'name', 
    });
  }  

  return { msgType => 'warning', message => "Resource ".$_[0]->{resource}." unknown"};
}

sub getAttributes ($$@) {
  my $command = shift;
  my $name = shift;
  my @lines = @_;

  my ($action, $resource) = ($command =~ /(.*)_(.*)/);
  my $attributes = { actionname => $action, resource => $resource, name => $name};
  $attributes->{action} = \&insert_update if ( $action eq 'insert' );
  $attributes->{action} = \&insert_update if ( $action eq 'update' );
  $attributes->{action} = \&delete        if ( $action eq 'delete' );

  foreach my $line (@lines) {
    my ($name, $value) = ($line =~ /^\s+(.*):(.*)$/);
    $name  =~ s/^\s+|\s+$//g if $name;
    $value =~ s/^\s+|\s+$//g if $value;
    $attributes->{$name} = $value;
  }

  return $attributes;
}

sub parse ($) {
  my $file = shift;
  my @jil = ();
  open FILE, "<$file" or die "Cannot open JIL file $file: $!";
    my @lines = ();
    my $name = '';
    my $command = '';
    my @commands = ();
    while (my $line = <FILE>) {
      chomp $line;
      if ($line =~ /^\s+(.*):(.*)$/) {  # If the line is a attribute-value pair
        push @lines, $line;   # Add that line to process it later
      } elsif ($line =~ /^(.*) +(.*)$/) { # If not, is it a command line
        if ( $command ne '' && $name ne '') {
          push @commands, getAttributes($command, $name, @lines);
          @lines = ();  
        }
        ($command, $name) = ($1, $2);
        $command =~ s/^\s+// if $command; # Trim it, just in case
        $name =~ s/\s+$// if $name; # Trim it, just in case
      }
    }
    # If reach the end of the file and do not process this command:
    push @commands, getAttributes($command, $name, @lines);
  close FILE;

  return $#commands != 0 ? \@commands : undef;
}

sub loadFile ($) {
  my $file = shift;

  my $jil = parse($file);
  return { msgType => 'warning', message => 'JIL syntax error or Empty file.' } unless $jil;

  # print Dumper($jil);
  my $return_result = { msgType => 'success', message => "" };
  my $result = {};
  foreach my $command (@$jil) {
    
    $result = $command->{action}->($command);
    print Dumper($command) if $result->{msgType} eq 'failure' ;
    $return_result->{msgType} = 'warning' if ( $result->{msgType} eq 'warning' and $return_result->{msgType} ne 'failure' );
    $return_result->{msgType} = 'failure' if ( $result->{msgType} eq 'failure' );
    $return_result->{message} = $return_result->{message}."<br>".ucfirst($result->{msgType}).": ".$result->{message};
  }
  $return_result->{message} = "JIL file successfuly loaded." if ( $return_result->{message} eq "" );

  return $return_result;
}

1;