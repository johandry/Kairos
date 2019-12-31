package Controller;

use strict;
use warnings;

use Dancer ':syntax';
use Dancer::Plugin::Database;
use Dancer::FileUtils qw/open_file path/;

use Time::Local;

use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

our $VERSION     = '1.00';
our @ISA         = qw(Exporter);
our @EXPORT      = qw(findAllOf findFirstOf intoDB accessLogEntry getAccessHistory amIAdmin getDBDate getDBToday pager replaceVariables);
our @EXPORT_OK   = qw(findAllOf findFirstOf intoDB accessLogEntry getAccessHistory amIAdmin getDBDate getDBToday pager replaceVariables);

# Variables in Scipts are: {FTG_SCRIPTS}, {source.filename}, {target.filename}, {filewatcher.filename}, {job.name}, {job.group}, {job.owner}, {job.description}, {command.scriptname}, {job.alarmto}
# {FTG_SCRIPTS}         : Path where doxTG store scripts in doxTG server  
# {source.filename}     : Filename to get by the Filetransfer Job. The Job need to be a Filetransfer.
# {source.host}         : Machine where to get the file to transfer in the format hostname.domainname. The Job need to be a Filetransfer.
# {source.ip}           : Machine IP where to get the file to transfer. The Job need to be a Filetransfer.
# {source.user}         : User to login to the source machine.
# {source.password}     : User password used to login to the source machine.
# {target.filename}     : Filename to put by the Filetransfer Job. The Job need to be a Filetransfer.
# {target.host}         : Machine where to put the file transfered in the format hostname.domainname. The Job need to be a Filetransfer.
# {target.ip}           : Machine IP where to put the file transfered. The Job need to be a Filetransfer.
# {filewatcher.filename}: Filename been watched by the Filewatcher. The Job need to have a Filewatcher trigger
# {filewatcher.host}    : Machine where to watch for the file to transfer in the format hostname.domainname. ThThe Job need to have a Filewatcher trigger.
# {filewatcher.ip}      : Machine where to watch for the file to transfer in the format hostname.domainname. ThThe Job need to have a Filewatcher trigger.
# {job.name}            : Name of the Job
# {job.group}           : Group of the Job
# {job.owner}           : Owner of the Job in the format "'Full Name' <email>"
# {job.description}     : Description of the Job
# {command.scriptname}  : Script name to be executed by the Command Job. The Job need to be a Command.
# {command.host}        : Machine where to execute the script in the format hostname.domainname. The Job need to be a Command.
# {command.ip}          : Machine IP where to execute the script. The Job need to be a Command.
# {job.alarmto}         : List of contacts to notify if the Job Fail or Success. Does not matter if the job is set to notify when fail or success.

sub replaceVariables ($$$) {
  my $parameters = shift;
  my $job = shift;
  my $source_file = shift;

  # {FTG_SCRIPTS}         : Path where doxTG store scripts in doxTG server 
  if ( $parameters =~ /{FTG_SCRIPTS}/ ) {
    my $ftg_scripts = path(setting('appdir'), 'scripts');
    $parameters =~ s/{FTG_SCRIPTS}/"$ftg_scripts"/g;
  }

  # {source.filename}     : Filename to get by the Filetransfer Job. The Job need to be a Filetransfer.
  if ( $parameters =~ /{source.filename}/ ) {
    my $action_type = findFirstOf('Actions', $job->{action_type});
    if ( $action_type->{name} eq 'Filetransfer' ) {
      $parameters =~ s/{source.filename}/"$source_file"/g;
    } else {
      # return undef;
      $parameters =~ s/{source.filename}/" "/g;
    }
  }

  # {source.host}         : Machine where to get the file to transfer in the format hostname.domainname. The Job need to be a Filetransfer.
  if ( $parameters =~ /{source.host}/ ) {
    my $action_type = findFirstOf('Actions', $job->{action_type});
    if ( $action_type->{name} eq 'Filetransfer' ) {
      my $filetransfer = findFirstOf('Filetransfers', $job->{action_id});
      my $source = findFirstOf('Containers', $filetransfer->{source_id});
      my $machine = findFirstOf('Machines', $source->{machine_id});
      my $host = "$machine->{hostname}.$machine->{domainname}";
      $parameters =~ s/{source.host}/"$host"/g;
    } else {
      # return undef;
      $parameters =~ s/{source.host}/" "/g;
    }
  }  

  # {source.ip}           : Machine IP where to get the file to transfer. The Job need to be a Filetransfer.
  if ( $parameters =~ /{source.ip}/ ) {
    my $action_type = findFirstOf('Actions', $job->{action_type});
    if ( $action_type->{name} eq 'Filetransfer' ) {
      my $filetransfer = findFirstOf('Filetransfers', $job->{action_id});
      my $source = findFirstOf('Containers', $filetransfer->{source_id});
      my $machine = findFirstOf('Machines', $source->{machine_id});
      my $ip = $machine->{ip};
      $parameters =~ s/{source.ip}/"$ip"/g;
    } else {
      # return undef;
      $parameters =~ s/{source.ip}/" "/g;
    }
  } 

  # {source.user}         : User to login to the source machine.
  if ( $parameters =~ /{source.user}/ ) {
    my $action_type = findFirstOf('Actions', $job->{action_type});
    if ( $action_type->{name} eq 'Filetransfer' ) {
      my $filetransfer = findFirstOf('Filetransfers', $job->{action_id});
      my $source = findFirstOf('Containers', $filetransfer->{source_id});
      my $credential = findFirstOf('Credentials', $source->{credential_id});
      my $username = $credential->{username};
      $parameters =~ s/{source.user}/"$username"/g;
    } else {
      # return undef;
      $parameters =~ s/{source.user}/" "/g;
    }
  }   

  # {source.password}     : User password used to login to the source machine.  
  if ( $parameters =~ /{source.password}/ ) {
    my $action_type = findFirstOf('Actions', $job->{action_type});
    if ( $action_type->{name} eq 'Filetransfer' ) {
      my $filetransfer = findFirstOf('Filetransfers', $job->{action_id});
      my $source = findFirstOf('Containers', $filetransfer->{source_id});
      my $credential = findFirstOf('Credentials', $source->{credential_id});
      my $password = $credential->{password};
      $password =~ s/\$/\\\$/g;
      $parameters =~ s/{source.password}/"$password"/g;
    } else {
      # return undef;
      $parameters =~ s/{source.password}/" "/g;
    }
  }  

  # {target.filename}     : Filename to put by the Filetransfer Job. The Job need to be a Filetransfer.
  if ( $parameters =~ /{target.filename}/ ) {
    my $action_type = findFirstOf('Actions', $job->{action_type});
    if ( $action_type->{name} eq 'Filetransfer' ) {
      my $filetransfer = findFirstOf('Filetransfers', $job->{action_id});
      my $target = findFirstOf('Containers', $filetransfer->{target_id});
      my $file = findFirstOf('Files', $target->{file_id});
      my $filename = $file->{name};
      $parameters =~ s/{target.filename}/"$filename"/g;
    } else {
      # return undef;
      $parameters =~ s/{target.filename}/" "/g;
    }
  }  

  # {target.host}         : Machine where to put the file transfered in the format hostname.domainname. The Job need to be a Filetransfer.
  if ( $parameters =~ /{target.host}/ ) {
    my $action_type = findFirstOf('Actions', $job->{action_type});
    if ( $action_type->{name} eq 'Filetransfer' ) {
      my $filetransfer = findFirstOf('Filetransfers', $job->{action_id});
      my $target = findFirstOf('Containers', $filetransfer->{target_id});
      my $machine = findFirstOf('Machines', $target->{machine_id});
      my $host = "$machine->{hostname}.$machine->{domainname}";
      $parameters =~ s/{target.host}/"$host"/g;
    } else {
      # return undef;
      $parameters =~ s/{target.host}/" "/g;
    }
  }  

  # {target.ip}           : Machine IP where to put the file transfered. The Job need to be a Filetransfer.
  if ( $parameters =~ /{target.ip}/ ) {
    my $action_type = findFirstOf('Actions', $job->{action_type});
    if ( $action_type->{name} eq 'Filetransfer' ) {
      my $filetransfer = findFirstOf('Filetransfers', $job->{action_id});
      my $target = findFirstOf('Containers', $filetransfer->{target_id});
      my $machine = findFirstOf('Machines', $target->{machine_id});
      my $ip = $machine->{ip};
      $parameters =~ s/{target.ip}/"$ip"/g;
    } else {
      # return undef;
      $parameters =~ s/{target.ip}/" "/g;
    }
  }   

  # {filewatcher.filename}: Filename been watched by the Filewatcher. The Job need to have a Filewatcher trigger
  if ( $parameters =~ /{filewatcher.filename}/ ) {
    my $trigger_type = findFirstOf('Triggers', $job->{trigger_type});
    if ( $trigger_type->{name} eq 'Filewatcher' ) {
      my $filewatcher = findFirstOf('Filewatchers', $job->{trigger_id});
      my $container   = findFirstOf('Containers', $filewatcher->{container_id});
      my $file        = findFirstOf('Files', $container->{file_id});
      my $filename    = $file->{name};
      $parameters =~ s/{filewatcher.filename}/"$filename"/g;
    } else {
      # return undef;
      $parameters =~ s/{filewatcher.filename}/" "/g;
    }
  }

  # {filewatcher.host}    : Machine where to watch for the file to transfer in the format hostname.domainname. ThThe Job need to have a Filewatcher trigger.
  if ( $parameters =~ /{filewatcher.host}/ ) {
    my $trigger_type = findFirstOf('Triggers', $job->{trigger_type});
    if ( $trigger_type->{name} eq 'Filewatcher' ) {
      my $filewatcher = findFirstOf('Filewatchers', $job->{trigger_id});
      my $container   = findFirstOf('Containers', $filewatcher->{container_id});
      my $machine = findFirstOf('Machines', $container->{machine_id});
      my $host = "$machine->{hostname}.$machine->{domainname}";
      $parameters =~ s/{filewatcher.host}/"$host"/g;
    } else {
      # return undef;
      $parameters =~ s/{filewatcher.host}/" "/g;
    }    
  }  

  # {filewatcher.ip}      : Machine where to watch for the file to transfer in the format hostname.domainname. ThThe Job need to have a Filewatcher trigger.
  if ( $parameters =~ /{filewatcher.ip}/ ) {
    my $trigger_type = findFirstOf('Triggers', $job->{trigger_type});
    if ( $trigger_type->{name} eq 'Filewatcher' ) {
      my $filewatcher = findFirstOf('Filewatchers', $job->{trigger_id});
      my $container   = findFirstOf('Containers', $filewatcher->{container_id});
      my $machine = findFirstOf('Machines', $container->{machine_id});
      my $ip = $machine->{ip};
      $parameters =~ s/{filewatcher.ip}/"$ip"/g;
    } else {
      # return undef;
      $parameters =~ s/{filewatcher.ip}/" "/g;
    }  
  }   

  # {job.name}            : Name of the Job
  if ( $parameters =~ /{job.name}/ ) {
    my $job_name = $job->{name};
    $parameters =~ s/{job.name}/"$job_name"/g;
  }

  # {job.group}           : Group of the Job
  if ( $parameters =~ /{job.group}/ ) {
    my $group = findFirstOf('JobGroups', $job->{group_id});
    my $group_name = $group->{name};
    $parameters =~ s/{job.group}/"$group_name"/g;
  }

  # {job.owner}           : Owner of the Job in the format "'Full Name' <email>"
  if ( $parameters =~ /{job.owner}/ ) {
    my $contact = findFirstOf('Contacts', $job->{contact_id});
    my $contact_info = "'$contact->{firstname} $contact->{lastname}' <$contact->{email}>";
    $parameters =~ s/{job.owner}/"$contact_info"/g;
  }

  # {job.description}     : Description of the Job
  if ( $parameters =~ /{job.description}/ ) {
    my $description = $job->{description};
    $parameters =~ s/{job.description}/"$description"/g;
  }  

  # {command.scriptname}  : Script name to be executed by the Command JOb. The Job need to be a Command.
  if ( $parameters =~ /{command.scriptname}/ ) {
    my $action_type = findFirstOf('Actions', $job->{action_type});
    if ( $action_type->{name} eq 'Command' ) {
      my $command = findFirstOf('Commands', $job->{action_id});
      my $container = findFirstOf('Containers', $command->{container_id});
      my $file = findFirstOf('Files', $container->{file_id});
      my $scriptname = $file->{name};
      $parameters =~ s/{command.scriptname}/"$scriptname"/g;
    } else {
      # return undef;
      $parameters =~ s/{command.scriptname}/" "/g;
    }
  }  

  # {command.host}        : Machine where to execute the script in the format hostname.domainname. The Job need to be a Command.
  if ( $parameters =~ /{command.host}/ ) {
    my $action_type = findFirstOf('Actions', $job->{action_type});
    if ( $action_type->{name} eq 'Command' ) {
      my $command = findFirstOf('Commands', $job->{action_id});
      my $container = findFirstOf('Containers', $command->{container_id});
      my $machine = findFirstOf('Machines', $container->{machine_id});
      my $host = "$machine->{hostname}.$machine->{domainname}";
      $parameters =~ s/{command.host}/"$host"/g;
    } else {
      # return undef;
      $parameters =~ s/{command.host}/" "/g;
    }
  }  

  # {command.ip}          : Machine IP where to execute the script. The Job need to be a Command.
  if ( $parameters =~ /{target.ip}/ ) {
    my $action_type = findFirstOf('Actions', $job->{action_type});
    if ( $action_type->{name} eq 'Command' ) {
      my $command = findFirstOf('Commands', $job->{action_id});
      my $container = findFirstOf('Containers', $command->{container_id});
      my $machine = findFirstOf('Machines', $container->{machine_id});
      my $ip = $machine->{ip};
      $parameters =~ s/{command.host}/"$ip"/g;
    } else {
      # return undef;
      $parameters =~ s/{command.host}/" "/g;
    }
  }

  # {job.alarmto}         : List of contacts to notify if the Job Fail or Success. Does not matter if the job is set to notify when fail or success.
  if ( $parameters =~ /{job.alarmto}/ ) {
    my @alarms = database->quick_select('Alarms', { job_id => $job->{id}});
    if ( @alarms ) {
      my @contacts = ();
      my $contact;
      foreach my $alarm (@alarms) {
        $contact = findFirstOf('Contacts', $alarm->{contact_id});
        push @contacts, "'$contact->{firstname} $contact->{lastname}' <$contact->{email}>"
      }  
      my $contacts_info = join(',', @contacts);
      $parameters =~ s/{job.alarmto}/"$contacts_info"/g;
    } else {
      # return undef;
      $parameters =~ s/{job.alarmto}/" "/g;
    }

  }

  return $parameters;
}

sub pager ($$$) {
  my $total        = shift;  
  my $per          = shift || 5;
  my $cur          = shift || 1;

  my $pager        = Data::SpreadPagination->new({
    totalEntries   => $total,
    entriesPerPage => $per,
    currentPage    => $cur,
    maxPages       => 10,
  });
  $pager->{per}    = $per;
  return $pager;
}

sub getDBDate () {
  my ($sec1, $min1, $hour1, $mday1, $mon1, $year1) = localtime();
  my $time = timelocal($sec1,$min1,$hour1,$mday1,$mon1,$year1);
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
  # my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  return sprintf("%4d-%02d-%02d %02d:%02d:%02d",$year+1900,$mon+1,$mday,$hour,$min,$sec);
}

sub getDBToday () {
  my ($sec1, $min1, $hour1, $mday1, $mon1, $year1) = localtime();
  my $time = timelocal($sec1,$min1,$hour1,$mday1,$mon1,$year1);
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
  # my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  return sprintf("%4d-%02d-%02d",$year+1900,$mon+1,$mday);
}

sub amIAdmin () {
  my $user    = session->{user};
  my $role_id = ${ database->quick_select('Users', { username => $user }, { colums => ['role_id'] }) }{role_id};
  # Admin role id should be 1, if not change it.
  return $role_id == 1
  # Consider to uncomment these 2 lines if you want to search by role name instead of role id
  # my $role    = ${ database->quick_select('Roles', { id => $role_id }, { colums => ['name'] }) }{name};
  # return $role eq 'Admin'

}

sub findAllOf ($) {
  my $tableName = shift;
  return database->quick_select($tableName, { });
}

sub findFirstOf ($$) {
  my ( $tableName, $id ) = @_;
  return database->quick_select($tableName, { id => $id });
}

sub intoDB ($$) {
  my $tableName = shift;
  my $values = shift;

  if ( $values->{id} ) {
    database->quick_update(ucfirst($tableName), { id => $values->{id} }, $values);
  } else {
    delete $values->{id};
    database->quick_insert(ucfirst($tableName), $values);
  }

  return database->err ? 0 : 1;
}

sub accessLogEntry($$) {
  my $request = shift;
  my $message = shift;

  my $ip            = $request->address() || '';
  my $remoteHost    = $request->remote_host() || '';
  my $remoteUser    = $request->user() || '';
  my $requestString = $request->to_string() || '';
  my $path = $request->path() || '';

  # my $action = '';

  # $action = "Rendering the Dashboard"                   if ( $requestString =~ /GET \// );
  # $action = "Rendering the $1 with id: $2"              if ( $requestString =~ /GET \/(.*)\/(.*)/ );
  # $action = "Rendering all $1"                          if ( $requestString =~ /GET \/(.*)/ );
  # $action = "Getting data to create a $1"               if ( $requestString =~ /GET \/(.*)\/new/ );
  # $action = "Creating a $1"                             if ( $requestString =~ /POST \/(.*)/ );
  # $action = "Getting data to update the $1 with id: $2" if ( $requestString =~ /GET \/(.*)\/(.*)\/edit/ );
  # $action = "Updating the $1 with id: $2"               if ( $requestString =~ /POST \/(.*)\/(.*)/ );
  # $action = "Deleting the $1 with id: $2"               if ( $requestString =~ /GET \/(.*)\/(.*)\/delete/ );
  # $action = "Running the Job with id: $2"               if ( $requestString =~ /GET \/jobs\/(.*)\/run/ );
  # $action = "Rendering status of Job with id: $2"       if ( $requestString =~ /GET \/jobs\/(.*)\/status/ );
  # $action = "Login"                                     if ( $requestString =~ /GET \/login/ );
  # $action = "Logout"                                    if ( $requestString =~ /GET \/logout/ );  


  my $now  = localtime(time);
  my $user = session->{user} if (session->{user});
  my $userData = session->{userdata} if (session->{userdata});
  my $logfile = path(setting('appdir'), 'logs', 'access.log');
  my $fh = open_file('>>', $logfile) or die "Could not open file '$logfile' $!";
  print $fh "$remoteHost ($ip) - $remoteUser - [$now] - $user - $userData - $requestString - $message\n";
  close $fh;
}

sub getAccessHistory() {
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
  my @days   = qw(Sun Mon Tue Wed Thr Fri Sat);
  my $today = sprintf("%s %2d",$months[$mon],$mday);
  $year += 1900;

  my $logfile = path(setting('appdir'), 'logs', 'access.log');
  my @lines = ();
  open (LOGFILE, $logfile) or die "Could not open file '$logfile' $!";
  while (<LOGFILE>){
    push @lines, $_ if /$today .* $year/;
  }
  my @entries = ();
  foreach (@lines) {
    if (/^.* - \[(.*)\] - .*login sucessful for user '(.*)' assigned to (.*) \(.*\)$/) {
      my ($accessTime, $username, $userFullName) = ($1, $2, $3);
      my $user_id = ${ database->quick_select('Users', { username => $username }, { colums => ['contact_id'] }) }{ contact_id };
      push @entries, { username => $username, userfullname => $userFullName, user_id => $user_id, accessTime => $accessTime };
    }
  }
  my $LASTEST_ACCESS = 5;
  # Get the last LASTEST_ACCESS elemets of the array which are the latest LASTEST_ACCESS users that logged in
  @entries = @entries[$#entries-$LASTEST_ACCESS+1 .. $#entries] if $#entries > $LASTEST_ACCESS;
  return \@entries;
}

true;
