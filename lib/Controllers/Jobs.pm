package Controllers::Jobs;

use strict;
use warnings;

use Dancer ':syntax';
use Dancer::Plugin::Database;
use Dancer::Plugin::FlashMessage;
use Dancer::FileUtils qw/path/;;
use Protocols;
use Controllers::Schedules;
use Controller qw(findAllOf findFirstOf intoDB getDBDate getDBToday replaceVariables);

use Dancer::Plugin::Email;
use Template;
use Text::CSV;
use Spreadsheet::WriteExcel;

=pod

=cut
sub getAllJobs {
  my $anyActionId     = database->quick_lookup('CommandTypes', { name => 'Any Action' }, 'id');
  my $pre_proActionId = database->quick_lookup('CommandTypes', { name => 'Pre/Post Action' }, 'id');
  my $preActionId     = database->quick_lookup('CommandTypes', { name => 'Pre Action' }, 'id');
  my $postActionId    = database->quick_lookup('CommandTypes', { name => 'Post Action' }, 'id');

  my @jobs = findAllOf('Jobs');  
  foreach my $job (@jobs) {
    my $owner = database->quick_select('Contacts', { id => $job->{contact_id} }, { columns => ['firstname', 'lastname', 'email', 'team_id'] });
    $job->{owner} = $owner->{firstname}." ".$owner->{lastname}." (".$owner->{email}.")";
    $job->{group} = database->quick_lookup('JobGroups', { id => $job->{group_id} }, 'name');
    #$owner->{team} = database->quick_lookup('Teams', { id => $owner->{team_id} }, 'name');
    my $action_type = database->quick_select('Actions', { id => $job->{action_type} }, { columns => ['name', 'table_name']});
    my $action = database->quick_select($action_type->{table_name}, { id => $job->{action_id} });
    $job->{action_type} = $action_type->{name};
    if ($action_type->{name} eq 'Filetransfer') {
      $job->{protocol} = database->quick_lookup('Protocols', { id => $action->{protocol_id} }, 'name');
      my $source       = database->quick_select('Containers', { id => $action->{source_id} });
      $job->{source}   = database->quick_lookup('Credentials', { id => $source->{credential_id} }, 'username')."@".database->quick_lookup('Machines', { id => $source->{machine_id} }, 'hostname');
      $job->{source_file} = database->quick_lookup('Files', { id => $source->{file_id} }, 'name');
      my $target       = database->quick_select('Containers', { id => $action->{source_id} });
      $job->{target}   = database->quick_lookup('Credentials', { id => $target->{credential_id} }, 'username')."@".database->quick_lookup('Machines', { id => $target->{machine_id} }, 'hostname');
      $job->{target_file} = database->quick_lookup('Files', { id => $target->{file_id} }, 'name');
    } elsif ($action_type->{name} eq 'Command') {
      my $command      = database->quick_select('Containers', { id => $action->{container_id} });
      $job->{command}  = database->quick_lookup('Credentials', { id => $command->{credential_id} }, 'username')."@".database->quick_lookup('Machines', { id => $command->{machine_id} }, 'hostname');
      $job->{script}   = database->quick_lookup('Files', { id => $command->{file_id} }, 'name');
      $job->{parameters}= $action->{parameters};
    }

    my $trigger_type = database->quick_select('Triggers', { id => $job->{trigger_type} }, { columns => ['name', 'table_name']});
    my $trigger = database->quick_select($trigger_type->{table_name}, { id => $job->{trigger_id} });
    $job->{action_type} = $trigger_type->{name};
    my $schedule;
    if ($trigger_type->{name} eq 'Filewatcher') {
      my $container = database->quick_select('Containers', { id => $trigger->{container_id} });
      $job->{filewatcher} = database->quick_lookup('Credentials', { id => $container->{credential_id} }, 'username')."@".database->quick_lookup('Machines', { id => $container->{machine_id} }, 'hostname');
      $job->{file_to_watch}= database->quick_lookup('Files', { id => $container->{file_id} }, 'name');
      $schedule = database->quick_select('Schedules', { id => $trigger->{schedule_id} });
    } elsif ($trigger_type->{name} eq 'Schedule') {
      $schedule = $trigger;
    } 

    $job->{schedule} = Controllers::Schedules::short_name($schedule)." (".Controllers::Schedules::long_name($schedule).")" if $schedule;

    my @preActions = database->quick_select('JobsCommands', { job_id => $job->{id}, type => [$preActionId, $pre_proActionId, $anyActionId] });
    $job->{pre_actions} = join ', ', map { database->quick_lookup('Commands', { id => $_->{command_id} }, 'name') } @preActions;

    my @postActions = database->quick_select('JobsCommands', { job_id => $job->{id}, type => [$postActionId, $pre_proActionId, $anyActionId] });   
    $job->{post_actions} = join ', ', map { database->quick_lookup('Commands', { id => $_->{command_id} }, 'name') } @postActions; 

    my @alarm_to = database->quick_select('Alarms', { job_id => $job->{id} }, { columns => ['contact_id'] });
    my @alarm_contacts_tmp = ();
    foreach my $alarmto (@alarm_to) {
      my $contact = database->quick_select('Contacts', { id => $alarmto->{contact_id} });
      push @alarm_contacts_tmp, $contact->{firstname}." ".$contact->{lastname}." (".$contact->{email}.")";
    }
    $job->{alarm_to} = join ', ', @alarm_contacts_tmp;
  }

  return @jobs;
}

sub to_csv () {
  my $csv_response = '';
  my $csv = Text::CSV->new ( );
  my @column_names = (
    'Job ID', 
    'Job Name', 
    'Group', 
    'Owner',
    'Description',
    'Active?', 
    'Alarm if Fail?',
    'Alarm if Success?',
    'Action Type',
    'Protocol',
    'Source Credential@Machine',
    'Source Filename',
    'Target Credential@Machine',
    'Target Filename',
    'Command Credential@Machine',
    'Command Script',
    'Parameters',
    'Trigger Type',
    'Filewatcher Credential@Machine',
    'File to Watch',
    'Schedule',
    'Pre-Actions',
    'Post-Actions',
    'Alarm to',
    );
  $csv->column_names(@column_names);
  $csv->combine(@column_names);
  $csv_response .= $csv->string();

  foreach (getAllJobs) {
    $csv->combine( ( 
      $_->{id}, 
      $_->{name}, 
      $_->{group}, 
      $_->{owner},
      $_->{description},
      $_->{active}, 
      $_->{alarm_if_fail},
      $_->{alarm_if_success},
      $_->{action_type},
      $_->{protocol} || 'N/A',
      $_->{source} || 'N/A',
      $_->{source_file} || 'N/A',
      $_->{target} || 'N/A',
      $_->{target_file} || 'N/A',
      $_->{command} || 'N/A',
      $_->{script} || 'N/A',
      $_->{parameters} || 'N/A',
      $_->{action_type},
      $_->{filewatcher} || 'N/A',
      $_->{file_to_watch} || 'N/A',
      $_->{schedule} || 'N/A',
      $_->{pre_actions},
      $_->{post_actions},
      $_->{alarm_to},
    ) );
    $csv_response .= "\n".$csv->string();
  }

  return $csv_response;
}

sub to_xls {
  open my $fhExcel, '>', \my $strExcel;
  my $workbook = Spreadsheet::WriteExcel->new($fhExcel);

  my $headerFormat = $workbook->add_format( 
    font         => 'Calibri',
    size         => 11,
    color        => 'white',
    bold         => 1,
    bg_color     => 30,
    bottom       => 1,
    top          => 1,
    bottom_color => 48,
    top_color    => 48,
    locked       => 1,
  ); 
  my @column_names = (
    'Job ID', 
    'Job Name', 
    'Group', 
    'Owner',
    'Description',
    'Active?', 
    'Alarm if Fail?',
    'Alarm if Success?',
    'Action Type',
    'Protocol',
    'Source Credential@Machine',
    'Source Filename',
    'Target Credential@Machine',
    'Target Filename',
    'Command Credential@Machine',
    'Command Script',
    'Parameters',
    'Trigger Type',
    'Filewatcher Credential@Machine',
    'File to Watch',
    'Schedule',
    'Pre-Actions',
    'Post-Actions',
    'Alarm to',
  );
  my $worksheet= $workbook->add_worksheet();
  $worksheet->write('A1', \@column_names, $headerFormat);
  my $oddRowFormat = $workbook->add_format( 
    font         => 'Calibri',
    size         => 11,
    color        => 'black',
    # bold         => 1,
    bg_color     => 44,
    bottom       => 1,
    top          => 1,
    bottom_color => 48,
    top_color    => 48,
    # locked       => 1,
  );
  my $evenRowFormat = $workbook->add_format( 
    font         => 'Calibri',
    size         => 11,
    color        => 'black',
    # bold         => 1,
    bg_color     => 41,
    bottom       => 1,
    top          => 1,
    bottom_color => 48,
    top_color    => 48,
    # locked       => 1,
  );
  my $row = 1;
  foreach (getAllJobs) {
    $worksheet->write("A$row", [
        $_->{id}, 
        $_->{name}, 
        $_->{group}, 
        $_->{owner},
        $_->{description},
        $_->{active}, 
        $_->{alarm_if_fail},
        $_->{alarm_if_success},
        $_->{action_type},
        $_->{protocol} || 'N/A',
        $_->{source} || 'N/A',
        $_->{source_file} || 'N/A',
        $_->{target} || 'N/A',
        $_->{target_file} || 'N/A',
        $_->{command} || 'N/A',
        $_->{script} || 'N/A',
        $_->{parameters} || 'N/A',
        $_->{action_type},
        $_->{filewatcher} || 'N/A',
        $_->{file_to_watch} || 'N/A',
        $_->{schedule} || 'N/A',
        $_->{pre_actions},
        $_->{post_actions},
        $_->{alarm_to},
        ], $row % 2 ? $oddRowFormat : $evenRowFormat );
    $row += 1;
  }

  $workbook->close();

  return $strExcel;
}

sub getInstances ($) {
  my $id = shift;
  return database->quick_select('JobInstances', { job_id => $id }, { order_by => { desc => 'id' }, limit => 10 });
}

sub checkTrigger ($) {
  my $job = shift;
  my $results;

  my $trigger_type = findFirstOf('Triggers', $job->{trigger_type});
  if ($trigger_type->{name} eq 'Filewatcher') {
    my $filewatcher = findFirstOf('Filewatchers', $job->{trigger_id});
    debug "Executing the job ".$job->{name}." triggered by ".$filewatcher->{name}.".";
    $results = Controllers::Filewatchers::check($filewatcher);
  } elsif ($trigger_type->{name} eq 'Condition') {
    my $condition = findFirstOf('Conditions', $job->{trigger_id});
    debug "Executing the job ".$job->{name}." triggered by ".$condition->{name}.".";
    $results = Controllers::Conditions::check($condition);
  } elsif ($trigger_type->{name} eq 'Schedule') {
    my $schedule = findFirstOf('Schedules', $job->{trigger_id});
    debug "Executing the job ".$job->{name}." triggered by ".$schedule->{name}.".";
    $results = Controllers::Schedules::check($schedule);
  }  
  return $results;
}

# sub getStatusID ($) {
#   my $status = shift;
#   return ${ database->quick_select('Statuses', { name => $status }, { colums => ['id'] }) }{id};
# }

sub executePreActions ($$$) {
  my $jobinstance = shift;
  my $job = shift;
  my $source_file = shift;

  my $preActionId = ${database->quick_select('CommandTypes', { name => 'Pre Action' })}{id};
  my @preActions  = database->quick_select('JobsCommands', { job_id => $jobinstance->{job_id}, type => $preActionId });

  return { msgType => 'success', message => "No Pre Actions to execute", jobinstance => $jobinstance, job => $job } if (! @preActions);

  foreach my $preAction (@preActions) {
    my $command = findFirstOf('Commands', $preAction->{command_id});
    my $container = findFirstOf('Containers', $command->{container_id});
    my $parameters = replaceVariables($command->{parameters}, $job, $source_file);
    # return { msgType => 'terminate', message => "The Job $job->{name} Pre Actions parameters of command $command->{name} are not valid for this Job Type or Trigger Type", jobinstance => $jobinstance, job => $job } } if ( ! defined $parameters );
    Protocols::ssh( $container, $parameters, $jobinstance->{id} );
    my $status_id = ${database->quick_select('JobInstances', { id => $jobinstance->{id} }, { colums => ['status_id'] })}{status_id}; 
    return { msgType => 'failure', message => "The Job ".$job->{name}." failed executing the pre action command ".$command->{name}.".", jobinstance => $jobinstance, job => $job } if ( $status_id == Protocols::getStatusID('FAILURE') )
  }

  return { msgType => 'success', message => "The Job ".$job->{name}." execute sucessfuly its pre actions.", jobinstance => $jobinstance, job => $job }
}

sub notify($$$) {
  my $job         = shift;
  my $jobinstance = shift;
  my $exit_code   = shift;

  return if ($exit_code == 0 and ! $job->{alarm_if_success});
  return if ($exit_code != 0 and ! $job->{alarm_if_fail});

  $jobinstance = database->quick_select('JobInstances', { id => $jobinstance->{id} });
  $jobinstance->{status} = database->quick_lookup('Statuses', { id => $jobinstance->{status_id} }, 'name');

  my @contact_id_alarm_to = database->quick_select('Alarms', { job_id => $job->{id} }, { columns => ['contact_id'] });
  my $to       = '';
  my @alarm_to = ();
  my $contact;
  foreach (@contact_id_alarm_to) {
    $contact = database->quick_select('Contacts', { id => $_->{contact_id} }, { columns => [qw(firstname lastname email)] } );
    $to .= "$contact->{firstname} $contact->{lastname} <$contact->{email}>; ";
    push @alarm_to, $contact;
  } 
  my $owner  = database->quick_select('Contacts', { id => $job->{contact_id} }, { columns => [qw(firstname lastname email)] });
  $job->{owner} = $owner;
  $to .= "$owner->{firstname} $owner->{lastname} <$owner->{email}>";
  push @alarm_to, $owner;
  $job->{alarm_to} = \@alarm_to;

  # Get table name instead of name because has the same name as the directory in emails
  my $action_type = database->quick_lookup('Actions', { id => $job->{action_type} }, 'table_name');

  $job->{group} = database->quick_lookup('JobGroups', { id => $job->{group_id} }, 'name');

  my $action = database->quick_select($action_type, { id => $job->{action_id} });
  if ($action_type eq 'Filetransfers') {
    $action->{protocol} = database->quick_lookup('Protocols', { id => $action->{protocol_id} }, 'name');
    $action->{source}   = database->quick_lookup('Containers', { id => $action->{source_id} }, 'name');
    $action->{target}   = database->quick_lookup('Containers', { id => $action->{target_id} }, 'name');
  } 
  $action->{type} = $action_type;

  my $trigger_type = database->quick_select('Triggers', { id => $job->{trigger_type} }, { columns => ['name', 'table_name']});
  my $trigger = database->quick_select($trigger_type->{table_name}, { id => $job->{trigger_id} });
  $trigger->{type} = $trigger_type->{name};


  my $template;
  my $variables= {
      jobinstance => $jobinstance,
      job         => $job,
      action      => $action,
      trigger     => $trigger,
      message     => '',
  };
  my $subject = "YP doxTG (". uc($jobinstance->{status})."): Job $job->{name} Status Notification";
  $template = lc ($action_type)."/".lc($jobinstance->{status}).".tt";
  # if ($exit_code == 0) {
  #   $template = lc ($action_type)."/success.tt";
  #   # $subject .= "(SUCCESS)";
  # } else {
  #   $template = lc ($action_type)."/failure.tt";
  #   # $subject .= "(FAILURE)";
  # }

  my $html = '';
  my $html_tt = Template->new({
    INCLUDE_PATH => path(setting('appdir'), 'emails'),
    INTERPOLATE  => 1,
    WRAPPER      => 'layouts/main_html.tt',
  });
  $html_tt->process($template, $variables, \$html);

  # my $text = '';
  # my $text_tt = Template->new({
  #   INCLUDE_PATH => path(setting('appdir'), 'emails'),
  #   INTERPOLATE  => 1,
  #   WRAPPER      => 'layouts/main_text.tt',
  # });
  # $text_tt->process('filetransfers/success.tt', { message => "Exit code is $exit_code" }, \$text);
  
  # Protocols::updateJobInstance($jobinstance->{id}, { results => "Notification sent." });
  my $result = email  {
    from      => 'doxTG <unixdo@yp.com>',
    to        => $to,
    # to        => 'ja6351@yp.com',
    subject   => $subject,
    type      => 'html',
    encoding  => "quoted-printable",
    body      => $html,
  }
}

sub execute ($$$) {
  my $params = shift;
  my $force  = shift;
  my $cli    = shift;
  my $id     = $params->{id};
  my $now;
  my $exit_code = 0;

  my $job = findFirstOf('Jobs', $id);

  unless (defined $job) {
    flash 'error' => "Job with ID $id is not defined";  
    return { msgType => 'failure', message => "Job with ID $id is not defined", jobinstance => undef, job => undef };  
  }

  if ( $job->{active} != 1 and ! $force ) {
    flash 'error' => "Job $job->{name} is not active and this is not a force start";  
    return { msgType => 'failure', message => "Job $job->{name} is not active and this is not a force start", jobinstance => undef, job => $job };      
  }

  my $start_on = getDBDate;

  my $status_id = Protocols::getStatusID('STARTING'); # database->quick_lookup('Statuses', { name => 'STARTING' }, 'id');

  database->quick_insert('JobInstances', { job_id => $id, start_on => $start_on, status_id => $status_id, results => "Job Start." });
  
  # my $jobinstance_id = database->last_insert_id( undef, undef, 'JobInstances', undef);
  # my $jobinstance = findFirstOf('JobInstances', $jobinstance_id);
  my $jobinstance = database->quick_select('JobInstances', { job_id => $id }, { order_by => { desc => 'id' }, limit => 1 });

  

  my $results = { msgType => 'success', message => "The Job ".$job->{name}." was sucessfuly started.", jobinstance => $jobinstance, job => $job };

  $results = checkTrigger($job) if ( ! $force );
  flash $results->{msgType} => $results->{message};
  return $results if ( $results->{msgType} ne 'success' );

  print "[".scalar localtime(time)."] - JOB - $id - STARTING - Starting Job $job->{name}. At ".__FILE__." line ".__LINE__.".\n" if $cli;  
  # my $thr;
  my $pid;
  my $jobinstanceUpdate;
  my $action_type = findFirstOf('Actions', $job->{action_type});
  if ( $action_type->{name} eq 'Filetransfer' ) {

    my $filetransfer = findFirstOf('Filetransfers', $job->{action_id});
    my $protocol     = findFirstOf('Protocols',  $filetransfer->{protocol_id});
    my $source       = findFirstOf('Containers', $filetransfer->{source_id});
    my $target       = findFirstOf('Containers', $filetransfer->{target_id});
    my $source_file  = database->quick_lookup('Files', { id => $source->{file_id} }, 'name');
    my $exit_code = 555;
    # $thr = threads->create("Protocols::".$protocol->{classname}, $source, $target, $jobinstance->{id});
    $pid = fork();
    if ($pid) {
      # This is the parent (DANCER)
      debug "Process started with PID $pid\n";
    } elsif ( $pid == 0 ) {
      # This is the child (PROTOCOL)
      print "[".scalar localtime(time)."] - PRC - $pid - STARTING - Starting process for Filetransfer Job $job->{name}. At ".__FILE__." line ".__LINE__.".\n" if $cli;
      if ( $source_file =~ /\*|\?/ ) {
        my @files = Protocols::ls( $source, $jobinstance->{id} );
        foreach my $file (@files) {
          print "[".scalar localtime(time)."] - JOB - $job->{id} - RUNNING - Executing Pre-Action for $job->{name} for file: $file. At ".__FILE__." line ".__LINE__.".\n" if $cli;
          $results = executePreActions($jobinstance, $job, $file);
          flash $results->{msgType} => $results->{message};  
          print "[".scalar localtime(time)."] - JOB - $job->{id} - RUNNING - Results of Pre-Action for $job->{name} for file: $file: ". ucfirst $results->{msgType}.": $results->{message}. At ".__FILE__." line ".__LINE__.".\n" if $cli;
          if ( $results->{msgType} ne 'success' ) {
            Protocols::updateJobInstance($jobinstance->{id}, { status => 'RUNNING', results => "The Pre-Actions have Failed at least for one file." });
            $exit_code = 55;
            last;
          } else {
            $exit_code = 0;
          }
        }
        if ( $exit_code == 0 ) {
          Protocols::updateJobInstance($jobinstance->{id}, { status => 'RUNNING', results => "The Pre-Actions were Successfuly executed with all the files to process." });

          # Get the file again as some of them may be renamed in the Pre-Actions.
          # TODO: Possible problem: If the source_file is '*.txt' and the Pre-Action change the files to '*.txt.DAT' the new files will not match.
          # SOLUTION: Instead of use '*.txt' use '*.txt*'
          @files = Protocols::ls( $source, $jobinstance->{id} );
          foreach my $file (@files) {
            # flash $results->{msgType} => $results->{message};  
            # $now  = localtime(time); print "    [$now] - Results executing Pre-Actions for $job->{name} - ". ucfirst $results->{msgType}.": $results->{message}\n" if $cli;
            # if ( $results->{msgType} ne 'success' ) {
            #   Protocols::updateJobInstance($jobinstance->{id}, { end_on => 1, status => 'FAILURE', exit_code => 55, results => "Fail to execute Pre-Actions." });
            #   $exit_code = 111;
            #   last;
            # } else {
            #   $exit_code = 0;
            # }

            $exit_code = Protocols::scp( { source => $source, source_file => $file, target => $target, jobinstance_id => $jobinstance->{id} }) if $protocol->{classname} eq 'scp';
            $exit_code = Protocols::sftp_bin({ source => $source, source_file => $file, target => $target, jobinstance_id => $jobinstance->{id} }) if $protocol->{classname} eq 'sftp_bin';
            $exit_code = Protocols::sftp_ascii({ source => $source, source_file => $file, target => $target, jobinstance_id => $jobinstance->{id} }) if $protocol->{classname} eq 'sftp_ascii';
            last if $exit_code > 0; 
          }
          if ( $exit_code > 0 ) {
            $jobinstanceUpdate = { end_on => 1, status => 'FAILURE', exit_code => $exit_code, results => "Some of the files to transfer failed." };
          } else {
            $jobinstanceUpdate = { end_on => 1, status => 'SUCCESS', exit_code => 0, results => "All the files were sucessfuly transfered." };
          }
        }
      } else {
        print "[".scalar localtime(time)."] - JOB - $job->{id} - RUNNING - Executing Pre-Actions for $job->{name}. At ".__FILE__." line ".__LINE__.".\n" if $cli;
        $results = executePreActions($jobinstance, $job, $source_file);
        print "[".scalar localtime(time)."] - JOB - $job->{id} - RUNNING - Results of Pre-Actions for $job->{name}: ". ucfirst $results->{msgType}.": $results->{message}. At ".__FILE__." line ".__LINE__.".\n" if $cli;
        flash $results->{msgType} => $results->{message};  
        if ( $results->{msgType} ne 'success' ) {
          Protocols::updateJobInstance($jobinstance->{id}, { status => 'RUNNING', results => "The Pre-Actions have Failed." });
          $exit_code = 55;
        }

        if ( $exit_code == 0 ) {
          $exit_code = Protocols::scp( { source => $source, source_file => undef, target => $target, jobinstance_id => $jobinstance->{id} }) if $protocol->{classname} eq 'scp';
          $exit_code = Protocols::sftp_bin({ source => $source, source_file => undef, target => $target, jobinstance_id => $jobinstance->{id} }) if $protocol->{classname} eq 'sftp_bin';
          $exit_code = Protocols::sftp_ascii({ source => $source, source_file => undef, target => $target, jobinstance_id => $jobinstance->{id} }) if $protocol->{classname} eq 'sftp_ascii';
        }
        if ( $exit_code > 0 ) {
          $jobinstanceUpdate = { end_on => 1, status => 'FAILURE', exit_code => $exit_code, results => "The Filetransfer have Failed" };
        } else {
          $jobinstanceUpdate = { end_on => 1, status => 'SUCCESS', exit_code => $exit_code, results => "The Filetransfer was a Success." };
        }
      }
      notify($job, $jobinstance, $exit_code);
      Protocols::updateJobInstance($jobinstance->{id}, $jobinstanceUpdate);
      print "[".scalar localtime(time)."] - JOB - $job->{id} - ".database->quick_lookup( 'Statuses', { id => $jobinstance->{status_id} }, 'name' )." - Ending Job $job->{name}. Exit Code: $exit_code. At ".__FILE__." line ".__LINE__.".\n" if $cli;
      exit $exit_code;
    } else {
      debug "Could not fork: $!\n";
    }

  } elsif ( $action_type->{name} eq 'Command' ) {

    my $command = findFirstOf('Commands', $job->{action_id});
    my $container = findFirstOf('Containers', $command->{container_id});

    # $thr = threads->create("Protocols::ssh", $container, $command->{parameters}, $jobinstance->{id});
    $pid = fork();
    if ($pid) {
      # This is the parent (DANCER)
      debug "Process started with PID $pid\n";
    } elsif ( $pid == 0 ) {
      # This is the child (PROTOCOL)
      print "[".scalar localtime(time)."] - PRC - $pid - STARTING - Starting process for Command Job $job->{name}. At ".__FILE__." line ".__LINE__.".\n" if $cli;
      my $parameters = replaceVariables( $command->{parameters}, $job, undef );
      # if ( ! defined $parameters ) {
      #   Protocols::updateJobInstance($jobinstance->{id}, { end_on => 1, status => 'TERMINATED', exit_code => 10, results => "The Job $job->{name} Pre Actions parameters of command $command->{name} are not valid for this Job Type or Trigger Type" });
      #   notify($job, $jobinstance, 10);
      # TODO: Add the status parameter to notify() to identify it, now it is identified by the exit code (1: SUCCESS, 0: FAILURE)
      #   exit 10;
      # }
      $exit_code = Protocols::ssh($container, $parameters, $jobinstance->{id});
      if ( $exit_code > 0 ) {
        $jobinstanceUpdate = { end_on => 1, status => 'FAILURE', exit_code => $exit_code, results => "Job Command execution have Failed." };
      } else {
        $jobinstanceUpdate = { end_on => 1, status => 'SUCCESS', exit_code => 0, results => "Job Command was Successfuly executed." };
      }
      notify($job, $jobinstance, $exit_code);
      Protocols::updateJobInstance($jobinstance->{id}, $jobinstanceUpdate);
      print "[".scalar localtime(time)."] - JOB - $job->{id} - ".database->quick_lookup( 'Statuses', { id => $jobinstance->{status_id} }, 'name' )." - Ending Job $job->{name}. Exit Code: $exit_code. At ".__FILE__." line ".__LINE__.".\n" if $cli;
      exit $exit_code;
    } else {
      debug "Could not fork: $!\n";
    }
  }

  if ($cli) {
    # $thr->join(); 
    my $output = waitpid($pid, 0);
    print "[".scalar localtime(time)."] - PRC - $pid - END - Fork process for Job $job->{name} have finished with output: $output. At ".__FILE__." line ".__LINE__.".\n";

    # print "Job Instance: ".$results->{jobinstance}->{id}."\n\n";
    # print "Started on:   ".$results->{jobinstance}->{start_on}."\n";
    # print "Start:        ".ucfirst($results->{msgType})."\n";
    # print "Message:      ".$results->{message}."\n\n"; 

  # } else {
  #   $thr->detach(); 
  }

  flash $results->{msgType} => $results->{message};  
  return $results
}

sub instance ($) {
  my $id = shift;
  my $jobinstance = database->quick_select('JobInstances', { id => $id } );
  $jobinstance->{status}  = ${ database->quick_select('Statuses', { id => $jobinstance->{status_id} }, { colums => ['name'] }) }{name};
  $jobinstance->{job}     = ${ database->quick_select('Jobs', { id => $jobinstance->{job_id} }, { colums => ['name'] }) }{name};
  #$jobinstance->{results} =~ s/\. /.<br>/g;
  if ($jobinstance->{results}) {
    $jobinstance->{results} =~ s/\n/<br\/>/g; 
    my @results = split '<br>', $jobinstance->{results};
    $jobinstance->{results} = \@results;
  }
  return { jobinstance => $jobinstance };
}

sub instances ($) {
  my $params = shift;
  my $id = $params->{id};

  my @jobinstances = getInstances($id);
  foreach my $jobinstance (@jobinstances) {
    $jobinstance->{status} = database->quick_lookup('Statuses', { id => $jobinstance->{status_id} }, 'name');
  }
  my $job = findFirstOf('Jobs', $id);

  return { job => $job, jobinstances => \@jobinstances, pager => Controller::pager(scalar @jobinstances, param( 'per' ), param( 'cur' )) }
}

sub todayinstances () {
  my $today = getDBToday;

  my @jobinstances = database->quick_select('JobInstances', { start_on => { 'like' => "$today%" } }, { order_by => { desc => 'id' } });
  foreach my $jobinstance (@jobinstances) {
    $jobinstance->{status} = database->quick_lookup('Statuses', { id => $jobinstance->{status_id} }, 'name');
    my $job = database->quick_select('Jobs', { id => $jobinstance->{job_id} }, { colums => ['name', 'group_id'] });
    $jobinstance->{job} = $job->{name};
    $jobinstance->{group} = database->quick_lookup('JobGroups', { id => $job->{group_id} }, 'name');
  }

  @jobinstances = grep { defined $_->{job} and defined $_->{group} } @jobinstances;

  return \@jobinstances
}

sub lastHourStats () {
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  my $lastHour = sprintf("%4d-%02d-%02d %02d:%02d:%02d",$year+1900,$mon+1,$mday,$hour-1,$min,$sec);

  my $failure_id  = Protocols::getStatusID('FAILURE'); # ${ database->quick_select('Statuses',    { name => 'FAILURE' },  { colums => ['id'] }) }{id};
  my $failure     = database->quick_count('JobInstances',    { status_id => $failure_id,  start_on => { 'ge' => $lastHour } });
  my $running_id  = Protocols::getStatusID('RUNNING'); # ${ database->quick_select('Statuses',    { name => 'RUNNING' },  { colums => ['id'] }) }{id};
  my $running     = database->quick_count('JobInstances',    { status_id => $running_id,  start_on => { 'ge' => $lastHour } });
  my $starting_id = Protocols::getStatusID('STARTING'); # ${ database->quick_select('Statuses',    { name => 'STARTING' }, { colums => ['id'] }) }{id};
  my $starting    = database->quick_count('JobInstances',    { status_id => $starting_id, start_on => { 'ge' => $lastHour } });

  return { failure => $failure, running => $running, starting => $starting }
}

sub todayStats () {
  my $today = getDBToday;

  my $success_id = Protocols::getStatusID('SUCCESS'); # ${ database->quick_select('Statuses',    { name => 'SUCCESS' }, { colums => ['id'] }) }{id};
  my $successful  =  database->quick_count('JobInstances', { start_on => { 'like' => "$today%" }, status_id => $success_id });
  my $failure_id = Protocols::getStatusID('FAILURE'); # ${ database->quick_select('Statuses',    { name => 'FAILURE' }, { colums => ['id'] }) }{id};
  my $failure  =  database->quick_count('JobInstances', { start_on => { 'like' => "$today%" }, status_id => $failure_id });
  my $terminated_id = Protocols::getStatusID('TERMINATED'); # ${ database->quick_select('Statuses',    { name => 'TERMINATED' }, { colums => ['id'] }) }{id};
  my $terminated  =  database->quick_count('JobInstances', { start_on => { 'like' => "$today%" }, status_id => $terminated_id });  
  my $executed   =  $successful + $failure + $terminated;

  return { executed => $executed, successful => $successful, failure => $failure, terminated => $terminated }
}

sub generalStats () {
  my $total = database->quick_count('Jobs', {});
  my $activeJobs = database->quick_count('Jobs', { active => 1 });
  return { total => $total, activeJobs => $activeJobs, inactiveJobs => $total - $activeJobs }
}

sub stats () {
  my $lastHourStats = lastHourStats();
  my $todayinstances = todayinstances();
  my $todayStats = todayStats();
  my $generalStats = generalStats();
  return { lastHourStats => $lastHourStats, jobinstances => $todayinstances, todayStats => $todayStats, generalStats => $generalStats }
}

sub create_update ($) {
  return 0 if ! Controller::amIAdmin;
  my $params = shift;
  ($params->{trigger_type}, $params->{trigger_id}) = split /:/, $params->{trigger_type};
  ($params->{action_type},  $params->{action_id})  = split /:/, $params->{action_type};

  my $post_actions   = $params->{post_actions};   delete $params->{post_actions};   $post_actions   = [ $post_actions ]   if ( defined $post_actions   and $post_actions   != 0 and ref( $post_actions )   ne 'ARRAY');
  my $pre_actions    = $params->{pre_actions};    delete $params->{pre_actions};    $pre_actions    = [ $pre_actions ]    if ( defined $pre_actions    and $pre_actions    != 0 and ref( $pre_actions )    ne 'ARRAY');
  my $alarm_contacts = $params->{alarm_contacts}; delete $params->{alarm_contacts}; $alarm_contacts = [ $alarm_contacts ] if ( defined $alarm_contacts and $alarm_contacts != 0 and ref( $alarm_contacts ) ne 'ARRAY');

  $params->{active} = 0 unless (exists $params->{active});
  $params->{alarm_if_fail} = 0 unless (exists $params->{alarm_if_fail});
  $params->{alarm_if_success} = 0 unless (exists $params->{alarm_if_success});

  if ( intoDB( 'Jobs', $params ) ) {
    if ( ! $params->{id} ) {
      delete $params->{id};
      $params->{id} = ${database->quick_select('Jobs', $params, { colums => ['id'] })}{id};
    }

    my $preActionId = ${database->quick_select('CommandTypes', { name => 'Pre Action' })}{id};
    if ( defined $pre_actions and $pre_actions == 0 ) {
      database->quick_delete('JobsCommands', { job_id => $params->{id}, type => $preActionId });
    } else {
      my @allPreActionsOfThisJob = database->quick_select('JobsCommands', { job_id => $params->{id}, type => $preActionId });
      foreach my $preActionOfThisJob (@allPreActionsOfThisJob) {
        database->quick_delete('JobsCommands', { id => $preActionOfThisJob->{id} }) unless ( $preActionOfThisJob->{command_id} ~~ @$pre_actions );
      }
      my @pre_actionsOfThisJob = map { $_->{command_id} } @allPreActionsOfThisJob;
      foreach my $pre_action (@$pre_actions) {
        database->quick_insert('JobsCommands', { job_id => $params->{id}, command_id => $pre_action, type => $preActionId }) unless ( $pre_action ~~ @pre_actionsOfThisJob );
      }      
    }

    
    my $postActionId = ${database->quick_select('CommandTypes', { name => 'Post Action' })}{id};
    if ( defined $post_actions and $post_actions == 0 ) {
      database->quick_delete('JobsCommands', { job_id => $params->{id}, type => $postActionId });
    } else {    
      my @allPostActionsOfThisJob = database->quick_select('JobsCommands', { job_id => $params->{id}, type => $postActionId });  
      foreach my $postActionOfThisJob (@allPostActionsOfThisJob) {
        database->quick_delete('JobsCommands', { id => $postActionOfThisJob->{id} }) unless ( $postActionOfThisJob->{command_id} ~~ @$post_actions );
      }
      my @post_actionsOfThisJob = map { $_->{command_id} } @allPostActionsOfThisJob;
      foreach my $post_action (@$post_actions) {
        database->quick_insert('JobsCommands', { job_id => $params->{id}, command_id => $post_action, type => $postActionId }) unless ( $post_action ~~ @post_actionsOfThisJob );  
      }
    }

    if ( defined $alarm_contacts and $alarm_contacts == 0 ) {
      database->quick_delete('Alarms', { id => $params->{id} });
    } else {      
      my @allAlarmContactsOfThisJob = database->quick_select('Alarms', { job_id => $params->{id} });
      foreach my $alarmContactOfThisJob (@allAlarmContactsOfThisJob) {
        database->quick_delete('Alarms', { id => $alarmContactOfThisJob->{id} }) unless ( $alarmContactOfThisJob->{contact_id} ~~ @$alarm_contacts );
      }
      foreach my $alarm_contact (@$alarm_contacts) {
        database->quick_insert('Alarms', { job_id => $params->{id}, contact_id => $alarm_contact }) unless ( $alarm_contact ~~ @allAlarmContactsOfThisJob );  
      }
    }

    return 1;
  }
  return 0;
}

# GET /jobs/new
# List all the Jobs
sub index () {
  my @jobs = findAllOf('Jobs');

  foreach my $job (@jobs) {
    my $action_type = database->quick_select('Actions', { id => $job->{action_type} }, { colums => ['name', 'table_name'] });
    $job->{action} = $action_type->{name}.": ".database->quick_lookup($action_type->{table_name}, { id => $job->{action_id} }, 'name');
    my $contact  = database->quick_select('Contacts',      { id => $job->{contact_id} });  
    $job->{contact} = $contact->{firstname}." ".$contact->{lastname};
    my $trigger_type  = database->quick_select('Triggers',      { id => $job->{trigger_type} }, { colums => ['name', 'table_name'] });  
    $job->{trigger_type} = $trigger_type->{name};
    # $job->{trigger} = $trigger_type->{name}.": ".database->quick_lookup($trigger_type->{table_name}, { id => $job->{trigger_id} }, 'name');
    $job->{group} = database->quick_lookup('JobGroups', { id => $job->{group_id} }, 'name');
  }

  return { jobs => \@jobs, pager => Controller::pager(scalar @jobs, param( 'per' ), param( 'cur' )) };
}

# GET /jobs/new
# Render a form to create a new Job
sub new () {
  return { error => "You need to be Admin to create a new Job." } if ! Controller::amIAdmin;
  my @actions = findAllOf('Actions');
  my @allActions = ();
  my $inActionId = database->quick_lookup('CommandTypes', { name => 'In Action' }, 'id');
  my $anyActionId = database->quick_lookup('CommandTypes', { name => 'Any Action' }, 'id');
  foreach my $action (@actions) {
    my @actionsOfThisType = ();
    if ( $action->{name} eq 'Command' ) {
      @actionsOfThisType = database->quick_select($action->{table_name}, { type => [$inActionId, $anyActionId] });
    } else {
      @actionsOfThisType = findAllOf($action->{table_name});
    }
    
    foreach my $actionOfThisType (@actionsOfThisType) {
      $actionOfThisType->{id}   = $action->{id}.":".$actionOfThisType->{id};
      $actionOfThisType->{name} = $action->{name}.":".$actionOfThisType->{name};        
    }
    push @allActions, @actionsOfThisType;
  } 
  # TODO: Make this with AJAX so when the user select a Trigger Type the form display only the Triggers of that type. This below is a temporary and bad "solution".
  my @triggers = findAllOf('Triggers');
  my @allTriggers = ();
  foreach my $trigger (@triggers) {
    my @triggersOfThisType = findAllOf($trigger->{table_name});
    foreach my $triggerOfThisType (@triggersOfThisType) {
      $triggerOfThisType->{id}   = $trigger->{id}.":".$triggerOfThisType->{id};
      $triggerOfThisType->{name} = $trigger->{name}.":".$triggerOfThisType->{name};
    }
    push @allTriggers, @triggersOfThisType;
  }

  my @contacts = findAllOf('Contacts');

  my $pre_proActionId = ${database->quick_select('CommandTypes', { name => 'Pre/Post Action' })}{id};

  my $preActionId = ${database->quick_select('CommandTypes', { name => 'Pre Action' })}{id};
  my @allPreActions = database->quick_select('Commands', { type => [$preActionId, $pre_proActionId, $anyActionId] });


  my $postActionId = ${database->quick_select('CommandTypes', { name => 'Post Action' })}{id};
  my @allPostActions = database->quick_select('Commands', { type => [$postActionId, $pre_proActionId, $anyActionId] });

  my @groups = findAllOf('JobGroups');

  return { allActions => \@allActions, allTriggers=>\@allTriggers, contacts => \@contacts, allPreActions => \@allPreActions, allPostActions => \@allPostActions, groups => \@groups };
}

# POST /jobs
# Insert/Create a new Job with the data provided from the create form.
sub create ($) {
  return { error => "You need to be Admin to create this Job." } if ! Controller::amIAdmin;
  my $params = shift;
    if ( create_update( $params ) ) {
    flash success => "Job '".$params->{name}."' sucessfuly created/updated.";
  } else {
    flash error => "Something happen, the Job '".$params->{name}."' could not be created/upated.";
  }; 
}

# GET /jobs/1/edit
# Render a Job data in a form to be updated.
sub edit ($) {
  return { error => "You need to be Admin to edit this Job." } if ! Controller::amIAdmin;
  my $params = shift;
  my $id = $params->{id};

  my $job = findFirstOf('Jobs', $id);
  my @actions = findAllOf('Actions');
  my @allActions = ();
  my $inActionId =  ${database->quick_select('CommandTypes', { name => 'In Action'  })}{id};
  my $anyActionId = ${database->quick_select('CommandTypes', { name => 'Any Action' })}{id};
  foreach my $action (@actions) {
    my @actionsOfThisType = ();
    if ( $action->{name} eq 'Command' ) {
      @actionsOfThisType = database->quick_select($action->{table_name}, { type => [$inActionId, $anyActionId] });
    } else {
      @actionsOfThisType = findAllOf($action->{table_name});
    }
    
    foreach my $actionOfThisType (@actionsOfThisType) {
      $actionOfThisType->{id}   = $action->{id}.":".$actionOfThisType->{id};
      $actionOfThisType->{name} = $action->{name}.":".$actionOfThisType->{name};        
    }
    push @allActions, @actionsOfThisType;
  }  
  # TODO: Make this with AJAX so when the user select a Trigger Type the form display only the Triggers of that type. This below is a temporary and bad "solution".
  my @triggers = findAllOf('Triggers');
  my @allTriggers = ();
  foreach my $trigger (@triggers) {
    my @triggersOfThisType = findAllOf($trigger->{table_name});
    foreach my $triggerOfThisType (@triggersOfThisType) {
      $triggerOfThisType->{id}   = $trigger->{id}.":".$triggerOfThisType->{id};
      $triggerOfThisType->{name} = $trigger->{name}.":".$triggerOfThisType->{name};
    }
    push @allTriggers, @triggersOfThisType;
  }

  my @contacts = findAllOf('Contacts');
  my @contactsOfThisJob = database->quick_select('Alarms', { job_id => $job->{id} });
  foreach my $contact (@contacts) {
    foreach my $contactOfThisJob (@contactsOfThisJob) {
      if ( $contactOfThisJob->{contact_id} == $contact->{id} ) {
        $contact->{selected} = 1;
        last;
      } 
    }
  }  

  my $pre_proActionId = ${database->quick_select('CommandTypes', { name => 'Pre/Post Action' })}{id};

  my $preActionId = ${database->quick_select('CommandTypes', { name => 'Pre Action' })}{id};
  my @allPreActions = database->quick_select('Commands', { type => [$preActionId, $pre_proActionId, $anyActionId] });
  my @preActionsOfThisJob = database->quick_select('JobsCommands', { job_id => $job->{id}, type => $preActionId });
  foreach my $preAction (@allPreActions) {
    foreach my $preActionOfThisJob (@preActionsOfThisJob) {
      if ( $preActionOfThisJob->{command_id} == $preAction->{id} ) {
        $preAction->{selected} = 1;
        last;
      } 
    }
  }

  my $postActionId = ${database->quick_select('CommandTypes', { name => 'Post Action' })}{id};
  my @allPostActions = database->quick_select('Commands', { type => [$postActionId, $pre_proActionId, $anyActionId] });
  my @postActionsOfThisJob = database->quick_select('JobsCommands', { job_id => $job->{id}, type => $postActionId });
  foreach my $postAction (@allPostActions) {
    foreach my $postActionOfThisJob (@postActionsOfThisJob) {
      if ( $postActionOfThisJob->{command_id} == $postAction->{id} ) {
        $postAction->{selected} = 1;
        last;
      } 
    }
  }  

  my @groups = findAllOf('JobGroups');  

  return { job => $job, allActions => \@allActions, allTriggers=>\@allTriggers, contacts => \@contacts, allPreActions => \@allPreActions, allPostActions => \@allPostActions, groups => \@groups  }
}

# POST /jobs/1
# Update a Job with the data provided from the edit form.
# TODO: Should be used PUT insted of POST but it cannot be in a form. Need to find a way to send a PUT request.
sub update ($) {
  return { error => "You need to be Admin to update this Job." } if ! Controller::amIAdmin;
  my $params = shift;
    if ( create_update( $params ) ) {
    flash success => "Job '".$params->{name}."' sucessfuly created/updated.";
  } else {
    flash error => "Something happen, the Job '".$params->{name}."' could not be created/upated.";
  }; 
}

# GET /jobs/1
# Render one Job
sub show ($) {
  my $params = shift;

  my $job = findFirstOf('Jobs', $params->{id});

  my $action_type = findFirstOf('Actions', $job->{action_type});
  my $action = findFirstOf($action_type->{table_name}, $job->{action_id});
  if ( $action_type->{name} eq 'Filetransfer' ) {
    $action->{source}   = findFirstOf('Containers', $action->{source_id});
    $action->{target}   = findFirstOf('Containers', $action->{target_id});
    $action->{protocol} = findFirstOf('Protocols', $action->{protocol_id});
  } elsif ( $action_type->{name} eq 'Command' ) {
    $action->{command}  = findFirstOf('Containers', $action->{container_id});
    $action->{type}     = findFirstOf('CommandTypes', $action->{type});
  }

  my $trigger_type = findFirstOf('Triggers', $job->{trigger_type});
  my $trigger = findFirstOf($trigger_type->{table_name}, $job->{trigger_id});
  if ($trigger_type->{name} eq "Filewatcher") {
    $trigger->{container} = ${ database->quick_select('Containers', { id => $trigger->{container_id} }, { colums => ['name'] } ) }{name};
    $trigger->{schedule}  = ${ database->quick_select('Schedules',  { id => $trigger->{schedule_id} },  { colums => ['name'] } ) }{name};
  } elsif ($trigger_type->{name} eq "Condition") {
    $trigger->{status}   = ${ database->quick_select('Statuses',  { id => $trigger->{status_id} },   { colums => ['name'] } ) }{name};
    $trigger->{job}      = ${ database->quick_select('Jobs',      { id => $trigger->{job_id} },      { colums => ['name'] } ) }{name};
    $trigger->{schedule} = ${ database->quick_select('Schedules', { id => $trigger->{schedule_id} }, { colums => ['name'] } ) }{name};
  }

  my $preActionId = ${database->quick_select('CommandTypes', { name => 'Pre Action' })}{id};
  my @preActions  = database->quick_select('JobsCommands', { job_id => $job->{id}, type => $preActionId });
  foreach my $preAct (@preActions) {
    $preAct->{command} = database->quick_select('Commands', { id => $preAct->{command_id} });
    $preAct->{command}->{file} = ${database->quick_select('Containers', { id => $preAct->{command}->{container_id} })}{name};
  }

  my $postActionId = ${database->quick_select('CommandTypes', { name => 'Post Action' })}{id};
  my @postActions  = database->quick_select('JobsCommands', { job_id => $job->{id}, type => $postActionId });
  foreach my $postAct (@postActions) {
    $postAct->{command} = database->quick_select('Commands', { id => $postAct->{command_id} });
    $postAct->{command}->{file} = ${database->quick_select('Containers', { id => $postAct->{command}->{container_id} })}{name};
  }  
  
  my $contact = findFirstOf('Contacts', $job->{contact_id});
  my $team = findFirstOf('Teams', $contact->{team_id});
  my $group = database->quick_lookup('JobGroups', { id => $job->{group_id} }, 'name');

  my @alarm_contacts_tmp = database->quick_select('Alarms', { job_id => $job->{id} });
  my @alarm_contacts = ();
  foreach my $contact_alarm (@alarm_contacts_tmp) {
    my $c = database->quick_select('Contacts', { id => $contact_alarm->{contact_id} });
    push @alarm_contacts, $c;
  } 
  
  return {
    job           => $job,
    action_type   => $action_type,
    action        => $action,
    pre_actions   => \@preActions,
    post_actions  => \@postActions,
    trigger_type  => $trigger_type,
    trigger       => $trigger,
    contact       => $contact,
    team          => $team,
    alarm_contacts=> \@alarm_contacts,
    group         => $group,
  }  
}

true;