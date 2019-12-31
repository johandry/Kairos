package Protocols;

use strict;
use warnings;

use Controller qw(findAllOf findFirstOf intoDB getDBDate replaceVariables);

use Dancer ':syntax';
use Dancer::Plugin::FlashMessage;
use Dancer::Plugin::Database;
use Dancer::FileUtils qw/open_file path/;
use File::Basename;
use Dancer::FileUtils qw/path/;;

use Net::SCP;
use Net::SCP::Expect;
use Net::SFTP::Foreign;
use Net::FTP;
use Net::SSH2;
#use Net::SSH2::Simple;

use utf8;

=pod

=cut

my %STATUSES = ( 
      INACTIVE    => 1,
      ACTIVATED   => 2,
      STARTING    => 3,
      RUNNING     => 4,
      SUCCESS     => 5,
      FAILURE     => 6,
      TERMINATED  => 7,
      RESTART     => 8,
      QUE_WAIT    => 9,
      ON_HOLD     => 10,
      ON_ICE      => 11,
    );


sub getStatusID ($) {
  my $status = shift;
  return $STATUSES{$status};
  # return ${ database->quick_select('Statuses', { name => $status }, { colums => ['id'] }) }{id};
}

sub updateJobInstance ($$) {
  my $jobinstance_id = shift;
  my $params = shift;
  my $date   = getDBDate; 
  
  my $exit_code = $params->{exit_code} ? $params->{exit_code} : "NaN";
  print "[".scalar localtime(time)."] - JOB - $jobinstance_id - $params->{status} - $params->{results} - Exit Code: $exit_code. At ".__FILE__." line ".__LINE__.".\n" unless defined request;
  info  "[".scalar localtime(time)."] - JOB - $jobinstance_id - $params->{status} - $params->{results} - Exit Code: $exit_code.\n";  
   
  $params->{status_id} = getStatusID($params->{status});
  delete $params->{status};
  if ( $params->{results} ) {
    my $results = ${database->quick_select('JobInstances', { id => $jobinstance_id }, { colums => ['results'] })}{results};
    $results = $results ? $results."<br>" : '';
    $params->{results} = $results."[$date] ".$params->{results};
  }
  $params->{end_on} = $date if ( $params->{end_on} );

  database->quick_update('JobInstances', { id => $jobinstance_id }, $params);
}

sub isSecure($) {
  my $command = shift;
  return 0 if $command =~ /rm /;
  return 0 if $command =~ /rmdir /;
  return 0 if $command =~ /password /;
  return 0 if $command =~ /passwd /;
  return 0 if $command =~ /sudo /;
  return 0 if $command =~ /su /;
  return 0 if $command =~ /shadow /;
  return 0 if $command =~ /group /;
  return 0 if $command =~ /;/;
  return 1;
}

sub executePostActions ($$) {
  my $jobinstance = shift;
  my $source_file = shift;

  my $job = findFirstOf('Jobs', $jobinstance->{job_id});

  my $postActionId = ${database->quick_select('CommandTypes', { name => 'Post Action' })}{id};
  my @postActions  = database->quick_select('JobsCommands', { job_id => $jobinstance->{job_id}, type => $postActionId });

  return { msgType => 'success', message => "The Job finish sucessfuly with no post actions to execute." } unless scalar(@postActions);

  foreach my $postAction (@postActions) {
    my $command = findFirstOf('Commands', $postAction->{command_id});
    my $container = findFirstOf('Containers', $command->{container_id});

    my $parameters = replaceVariables( $command->{parameters}, $job, $source_file );
    # return { msgType => 'terminate', message => "The Job $job->{name} Post Actions parameters of $command->{name} are not valid for this Job Type or Trigger Type" } if ( ! defined $parameters );
    Protocols::ssh( $container, $parameters, $jobinstance->{id} );
    my $status_id = ${database->quick_select('JobInstances', { id => $jobinstance->{id} }, { colums => ['status_id'] })}{status_id}; 
    return { msgType => 'failure', message => "The Job failed executing the post action command ".$command->{name}."." } if ( $status_id == getStatusID('FAILURE') )
  }

  return { msgType => 'success', message => "The Job execute sucessfuly its post actions." }
}

sub execCommand ($$) {
    my $ssh2 = shift;
    my $cmd  = shift;

    my %args=(
      timeout => 1_000,  # polling timeout
      bufsize => 10_240, # read buffer size when polling
    );
    
    $ssh2->blocking(1); #needed for ssh->channel
    my $chan=$ssh2->channel(); # create SSH2 channel
    if ($ssh2->error()) {
      debug("Cannot open SSH2 channel");
      return (undef, undef, 100);
    }

    # exec $cmd (caveat: only one command line can be executed over this channel. No "ls -l;whoami" combo. Use ssh->shell instead.
    unless ($chan->exec($cmd)) {
      debug("Cannot exec '$cmd' over SSH2 channel");
      return (undef, undef, 500);
    }
    
    # defin polling context: will poll stdout (in) and stderr (ext)
    my @poll = ( { handle => $chan, events => ['in','ext'] } );
    
    my %std=();     # hash of strings. store stdout/stderr results
    $ssh2->blocking( 0 ); # needed for channel->poll
    while(!$chan->eof) { # there still something to read from channel
        $ssh2->poll( $args{'timeout'}, [ @poll ] ); # if any event, it will be store into $poll;

        my( $n, $buf ); # number of bytes read (n) into buffer (buf)
        foreach my $poll ( @poll ) { # for each event
            foreach my $ev ( qw( in ext ) ) { #for each stdout/stderr
                next unless $poll->{revents}{$ev};

                #there are something to read here, into $std{$ev} hash
                if( $n = $chan->read( $buf, $args{'bufsize'}, $ev eq 'ext' ) ) { #got n byte into buf for stdout ($ev='in') or stderr ($ev='ext')
                    $std{$ev}.=$buf;
                }
            } #done foreach
        }
    }
    $chan->wait_closed(); #not really needed but cleaner
    
    my $exit_code=$chan->exit_status();
    $chan->close(); #not really needed but cleaner
    
    $ssh2->blocking(1); # set it back for sanity (future calls)

    return ($std{'in'},$std{'ext'},$exit_code);
}

sub lastModification ($) {
  my $container   = shift;

  my $cmd = "[[ \"\$(/usr/sbin/lsof -u ".$container->{credential}->{username}." | grep ".$container->{file}->{name}." | awk '{ print \$9 }')\" != \"\" ]] || stat -c %y ".$container->{file}->{name};

  my ($stdout, $stderr, $exitcode);
  my $ssh2 = Net::SSH2->new();
  $ssh2->connect( $container->{machine}->{ip} ) or error("Cannot connect to ".$container->{machine}->{ip});
  debug "Connected to $container->{machine}->{ip}";
  my $publicKeyFile  = path(setting('appdir'), 'db', 'id_rsa.pub');
  my $privateKeyFile = path(setting('appdir'), 'db', 'id_rsa');
  if ( $ssh2->auth_publickey( $container->{credential}->{username}, $publicKeyFile, $privateKeyFile, $container->{credential}->{password} ) ) {
    ($stdout, $stderr, $exitcode) = execCommand($ssh2, $cmd);
  } else {
    debug "Could not authenticate to $container->{machine}->{hostname} ($container->{machine}->{ip}) with $container->{credential}->{username}";
  }

  my $lastModification = $stdout || 0;

  $ssh2->disconnect();
  undef $ssh2;

  return $lastModification;
}

sub isOpen ($$) {
  my $container      = shift;
  my $jobinstance_id = shift;

  # TODO: stat command is not working on fhprod20. We need to find another way to check if a file is open in HPUX 
  # my $lastModification = lastModification( $container );
  my $lastModification = "The command stat is not in fhprod20. So, do not check if a file is open.";
  my $msg;
  my $date;

  if ( ! $lastModification ) { # If lastModification is 0/false then the file is not closed
    my $end_on    = getDBDate;
    # my $status_id = getStatusID( 'FAILURE' ); 
    my $exit_code = 10;
       $msg       = "Source file '".$container->{file}->{name}."' is not closed or not exists.";
    updateJobInstance($jobinstance_id, { end_on => $end_on, status => 'FAILURE', exit_code => $exit_code, results => $msg });   
  } else {
    # my $status_id = getStatusID( 'RUNNING' );
       $msg       = "Source file '".$container->{file}->{name}."' is closed and ready to be transfered.";
    updateJobInstance($jobinstance_id, { status => 'RUNNING', results => $msg });
  }

  debug $msg;
  return not $lastModification;
}

sub getContainer ($) {
  my $container = shift;

  return undef if ! $container;

  my $machine    = findFirstOf('Machines', $container->{machine_id});
  my $credential = findFirstOf('Credentials', $container->{credential_id});
  my $file       = findFirstOf('Files', $container->{file_id});

  return { machine => $machine, credential => $credential, file => $file }
}

sub ls ($$) {
  my $source = getContainer shift;
  my $jobinstance_id      = shift;

  my $cmd = "ls -ld ".$source->{file}->{name}." | grep -v '^d' | awk '{ print \$9 }' ";

  my @files = ();
  my $ssh2 = Net::SSH2->new();
  if ( $ssh2->connect( $source->{machine}->{ip} ) ) {
    debug "Connected to $source->{machine}->{ip} to get the list of files $source->{file}->{name}";
    my $publicKeyFile  = path(setting('appdir'), 'db', 'id_rsa.pub');
    my $privateKeyFile = path(setting('appdir'), 'db', 'id_rsa');
    if ( $ssh2->auth_publickey( $source->{credential}->{username}, $publicKeyFile, $privateKeyFile, $source->{credential}->{password} ) ) {
      my ($stdout, $stderr, $exitcode) = execCommand($ssh2, $cmd);
      @files = split /\n/, $stdout;
    } else {
      error "Could not authenticate to $source->{machine}->{hostname} ($source->{machine}->{ip}) with $source->{credential}->{username} to get the list of files $source->{file}->{name}";
      updateJobInstance($jobinstance_id, { end_on => 1, status => 'FAILURE', exit_code => 100, results => "Could not authenticate to $source->{machine}->{hostname} to get the list of files $source->{file}->{name}" });
    }
    chomp @files;
    # @files = grep ! /\.FIN/, @files;

  } else {
    debug("Cannot connect to $source->{machine}->{ip} with SSH to get the list of files $source->{file}->{name}, trying with FTP.");
    my $status = 'success';
    # If SSH is not enable then try with FTP
    my $ftp = Net::FTP->new( $source->{machine}->{ip}, Debug => 0, Passive => 0) or $status = 'failure';
    if ($status eq 'failure') {
      error "Cannot connect to $source->{machine}->{ip} with SSH neither FTP to get the list of files $source->{file}->{name}. Exit code: 105";
      updateJobInstance($jobinstance_id, { end_on => 1, status => 'FAILURE', exit_code => 105, results => "Cannot connect to $source->{machine}->{ip} with SSH neither FTP to get the list of files $source->{file}->{name} to get the list of files $source->{file}->{name}" });
      return undef;
    };

    # Login to the target with FTP
    $ftp->login( $source->{credential}->{username}, $source->{credential}->{password} ) or $status = 'failure';
    if ($status eq 'failure') {
      error "Could not login to $source->{machine}->{hostname} ($source->{machine}->{ip}) with $source->{credential}->{username} to get the list of files $source->{file}->{name}. Error Message: $ftp->message. Exit code: 106";
      updateJobInstance($jobinstance_id, { end_on => 1, status => 'FAILURE', exit_code => 106, results => "Could not authenticate to $source->{machine}->{hostname} ($source->{machine}->{ip}) with $source->{credential}->{username} to get the list of files $source->{file}->{name}" });
      return undef;
    };
    
    debug "Source: ".$source->{file}->{name};
    $source->{file}->{name} =~ /(.*)\//;
    my $dir = $1."/";
    debug "Dir: $dir";
    $ftp->cwd($dir) or $status = 'failure';
    if ($status eq 'failure') {
      error "Cannot change directory to $dir to get the list of files $source->{file}->{name}. Exit code: 110";
      updateJobInstance($jobinstance_id, { end_on => 1, status => 'FAILURE', exit_code => 110, results => "Cannot change directory to $dir to get the list of files $source->{file}->{name}. Error Message: $ftp->message. Exit code: 110" });
      return undef;
    };

    my @no_dir = $ftp->dir($source->{file}->{name});
    debug "No Dir 1: ".join(',',@no_dir);
    @no_dir = grep {!/^d/} @no_dir;
    debug "No Dir 2: ".join(',',@no_dir);

    @files = $ftp->ls($source->{file}->{name});
    # The return of ls is the list of files and directories with absolute path, to eliminate the directories and keep the files:
    # 1. Remove the dir from the files
    # 2. Get the files that are in the no directories list by checking each file match with every elemement of the no directories list
    # 3. and put the dir back to the begining again
    # No, I was not smoking nohing when I did this.
    @files = map { $dir.$_ } grep { my $f = $_;  grep { /$f/ } @no_dir } map { $_ =~ s/$dir//; $_ } @files;
  }

  if ( scalar @files ) {
    updateJobInstance($jobinstance_id, { status => 'RUNNING', results => "Files to transfer: ".join( ', ', @files ) });
  } else {
    updateJobInstance($jobinstance_id, { status => 'FAILURE', results => "No files found in $source->{file}->{name}." });
  }

  $ssh2->disconnect();
  undef $ssh2;

  return @files;  
}

sub existsFile($) {
  my $container = getContainer shift;

  my $exists_cmd = '';
  if ( $container->{file}->{name} =~ /\*|\?/ ) {
    $exists_cmd = "ls -ld $container->{file}->{name} | grep -qv '^d' && echo 'OK'";
  } else {
    $exists_cmd = "[[ -f \"$container->{file}->{name}\" ]] && echo 'OK'";
  }
  # my $exit_code = 0;
  my ($stdout, $stderr, $exit_code);
  my $msgType = 'failure';
  my $message = "Cannot connect to ".$container->{machine}->{hostname};

  my $ssh2 = Net::SSH2->new();
  if ($ssh2->connect( $container->{machine}->{ip} )) {
    my $publicKeyFile  = path(setting('appdir'), 'db', 'id_rsa.pub');
    my $privateKeyFile = path(setting('appdir'), 'db', 'id_rsa');
    if ( $ssh2->auth_publickey( $container->{credential}->{username}, $publicKeyFile, $privateKeyFile, $container->{credential}->{password} ) ) {
      ($stdout, $stderr, $exit_code) = execCommand($ssh2, $exists_cmd);
      $stdout = "" unless $stdout;
      $stderr = "" unless $stderr;
      chomp $stdout;
      chomp $stderr;

      if ($stdout eq 'OK') {
        $msgType = 'success';
        $message = "Files exists: $container->{file}->{name} (STDOUT: $stdout, STDERR: $stderr, EXITCODE: $exit_code)";
      } else {
        $message = "Files NOT found: $container->{file}->{name} (STDOUT: $stdout, STDERR: $stderr, EXITCODE: $exit_code)";
      }
    } else {
      $exit_code = 1;
      $message = "Cannot authenticate to ".$container->{credential}->{username}."@".$container->{machine}->{hostname};
    }
  } else {
    debug("Cannot connect to $container->{machine}->{ip} with SSH to verify if $container->{file}->{name} exists, trying with FTP");
    # If SSH is not enable then try with FTP
    my $ftp = Net::FTP->new( $container->{machine}->{ip}, Debug => 0, Passive => 0) or return { msgType => $msgType, message => "Cannot connect to $container->{machine}->{ip} with SSH neither FTP to verify if $container->{file}->{name} exists. Exit code: 5" };

    # Login to the target with FTP
    $ftp->login( $container->{credential}->{username}, $container->{credential}->{password} ) or return { msgType => $msgType, message => "Cannot login to $container->{machine}->{ip} with $container->{credential}->{username} to verify if $container->{file}->{name} exists. Exit code: 6" };

    my @files = $ftp->dir($container->{file}->{name});
    @files = grep {!/^d/} @files;

    if (scalar @files) {
      $msgType = 'success';
      $exit_code = 0;
      $message = "File exists (OK)";
    } else {
      $msgType = 'failure';
      $exit_code = 1;
      $message = "File not found (".join(', ', @files).")";
    }

  }
  $ssh2->disconnect(); undef $ssh2;
  return { msgType => $msgType, message => "$message. Exit code: $exit_code" }
}

sub getTmpFilename ($$) {
  my $jobinstance_id = shift;
  my $path = shift;  
  my ($filename, $directories, $suffix) = fileparse( $path );
  return path(setting('appdir'), 'var', $jobinstance_id."_IN_".$filename);
}

sub getFileDirectory ($) {
  my $path = shift;  
  my ($filename, $directories, $suffix) = fileparse( $path );
  return $directories;
}

sub ssh ($$$) {
  my $container     = getContainer shift;
  my $parameters    = shift;
  my $jobinstance_id = shift;

  my ($stdout, $stderr, $exit_code);

  my $cmd = $container->{file}->{name}." ".$parameters;
  my $exists_cmd = "[[ -x \"$container->{file}->{name}\" ]] && $cmd";

  my $msg       = "Running job will execute '$cmd' in ".$container->{machine}->{hostname}.". ";
  my $status = 'RUNNING'; 
  # my $exit_code;

  unless ( isSecure($cmd) ) {
    $msg       = "Command '$cmd' is not secure. It have a possible dangerous command. Check with the ypFTG Administrator.";
    # $status_id = getStatusID( 'FAILURE' ); 
    $exit_code = 2;
    updateJobInstance($jobinstance_id, { end_on => 1, status => 'FAILURE', exit_code => $exit_code, results => $msg });
    return $exit_code;
  }  

  updateJobInstance($jobinstance_id, { status => $status, results => $msg });
  my $ssh2 = Net::SSH2->new();
  # my $ssh2 = Net::SSH2::Simple->new();
  unless ($ssh2->connect( $container->{machine}->{ip} )) {
    debug("Cannot connect to ".$container->{machine}->{ip});
    return 50;
  }
  # $ssh2->blocking(0);
  my $publicKeyFile  = path(setting('appdir'), 'db', 'id_rsa.pub');
  my $privateKeyFile = path(setting('appdir'), 'db', 'id_rsa');
  if ( $ssh2->auth_publickey( $container->{credential}->{username}, $publicKeyFile, $privateKeyFile, $container->{credential}->{password} ) ) {
    ($stdout, $stderr, $exit_code) = execCommand($ssh2, $exists_cmd);

    $stdout = "\n<b>Stdout</b>: ".($stdout ? $stdout : "<i>NOTHING</i>")."\n";
    $stdout .= "<b>Stderr</b>: ".($stderr ? $stderr : "<i>NOTHING</i>")."\n";
    $stdout .= "<b>Exit code</b>: ".($exit_code ? $exit_code : 0); 

    $msg       = "Command successfuly executed with output: $stdout.";
    $status = $exit_code ? 'FAILURE' : 'SUCCESS';
    updateJobInstance($jobinstance_id, { end_on => 1, status => $status, exit_code => $exit_code, results => $msg });
  
  } else {
    $msg       = "Cannot connect to $container->{machine}->{hostname} with user $container->{credential}->{username}. ";
    $status = 'FAILURE'; 
    $exit_code = 1;
    updateJobInstance($jobinstance_id, { end_on => 1, status => $status, exit_code => $exit_code, results => $msg });
  }

  $ssh2->disconnect(); undef $ssh2;
  return $exit_code;
}

sub failProtocol($) {
  my $param = shift;
  my $msg = $param->{error} ? $param->{error_message} : $param->{ok_message};
  updateJobInstance($param->{jobinstance_id}, { status => 'RUNNING', results => $msg });  
  return $param->{error};
}

sub exitProtocol ($) {
  my $param = shift;
  updateJobInstance($param->{jobinstance_id}, { end_on => 1, status => 'FAILURE', exit_code => $param->{exitcode}, results => $param->{msg} });
}

sub sftp ($$) {
  my $source = getContainer $_[0]->{source};
  my $target = getContainer $_[0]->{target};
  my $jobinstance_id      = $_[0]->{jobinstance_id};
  my $binary_ftp          = $_[1];

  if ( $_[0]->{source_file} ) {
    $source->{file}->{name} = $_[0]->{source_file};
    my ($filename, $directories, $suffix) = fileparse( $source->{file}->{name} );
    $target->{file}->{name} = $target->{file}->{name}."/".$filename;
  }

  return 999 if isOpen( $source, $jobinstance_id );
  
  my $msg;
  # my @status     = 'success';
  my $tmp_file   = getTmpFilename( $jobinstance_id, $source->{file}->{name} );
  my $status     = 'STARTING';
  my $exit_code  = 0;
  my $ftp;
  my $error_message = "File ".$source->{credential}->{username}."@".$source->{machine}->{hostname}.":".$source->{file}->{name}." was not transfered to ".$target->{credential}->{username}."@".$target->{machine}->{hostname}.":".$target->{file}->{name}.".";

  # Connect to source
  my $sftp = Net::SFTP::Foreign->new( host => $source->{machine}->{ip}, user => $source->{credential}->{username}, password => $source->{credential}->{password} );
  if ( failProtocol({
    jobinstance_id => $jobinstance_id,
    error => $sftp->error, 
    error_message => "Cannot connect source ".$source->{machine}->{hostname}.". Error: ".$sftp->error.". Status: ".$sftp->status, 
    ok_message => "SFTP connection established to ".$source->{machine}->{hostname}."." 
    }) ) {
    $sftp->disconnect;
    # If SFTP connection failed, let's try with FTP

    # Connect to source with FTP
    # Passive Mode set to 0 so it is not used. This is because for some servers Passive Mode does not work.
    my $ftp = Net::FTP->new( $source->{machine}->{ip}, Debug => 0, Passive => 0) or $status = 'FAILURE';
    
    if ( failProtocol({ 
      jobinstance_id => $jobinstance_id,
      error => $status eq 'FAILURE', 
      error_message => "Cannot connect to ".$source->{machine}->{hostname}." with FTP. Error Message: ".$@, 
      ok_message => "FTP connection established to ".$source->{machine}->{hostname}."." 
      }) ) {
      $exit_code = 6;
      exitProtocol({ jobinstance_id => $jobinstance_id, exitcode => $exit_code, msg => $error_message });
      return $exit_code;
    }

    # Login to the target with FTP
    $ftp->login( $source->{credential}->{username}, $source->{credential}->{password} ) or $status = 'FAILURE';
    if ( failProtocol({ 
      jobinstance_id => $jobinstance_id,
      error => $status eq 'FAILURE', 
      error_message => "Cannot login to ".$source->{machine}->{hostname}." with ".$source->{credential}->{username}.". Error Message: ".$ftp->message, 
      ok_message => "FTP login sucessful to ".$source->{machine}->{hostname}." with ".$source->{credential}->{username}."." 
      }) ) {
      $exit_code = 7;
      exitProtocol({ jobinstance_id => $jobinstance_id, exitcode => $exit_code, msg => $error_message }); $ftp->quit;
      return $exit_code;
    }

    if ($binary_ftp) {
      $ftp->binary;  
    } else {
      $ftp->ascii;
    }    

    # Get the file to the source with FTP
    $ftp->get( $source->{file}->{name}, $tmp_file ) or $status = 'FAILURE';
    if ( failProtocol({ 
      jobinstance_id => $jobinstance_id,
      error => $status eq 'FAILURE', 
      error_message => "Cannot get the file ".$source->{file}->{name}."@".$source->{machine}->{ip}.". Error Message: ".$ftp->message, 
      ok_message => "File ".$source->{credential}->{username}."@".$source->{machine}->{hostname}.":".$source->{file}->{name}." successfuly transfered to ypFTG server."
      }) ) {
      $exit_code = 8;
      exitProtocol({ jobinstance_id => $jobinstance_id, exitcode => $exit_code, msg => $error_message }); $ftp->quit;
      return $exit_code;
    }

    $ftp->quit;

  } else {
    # SFTP is working, lets get the file.
    # Get the file from the source
    $sftp->get( $source->{file}->{name}, $tmp_file );
    if ( failProtocol({ 
      jobinstance_id => $jobinstance_id,
      error => $sftp->error, 
      error_message => "Cannot get the file ".$source->{file}->{name}."@".$source->{machine}->{ip}.". Error: ".$sftp->error.". Status: ".$sftp->status, 
      ok_message => "File ".$source->{credential}->{username}."@".$source->{machine}->{hostname}.":".$source->{file}->{name}." successfuly transfered to ypFTG server." 
      }) ) {
      $exit_code = 2;
      exitProtocol({ jobinstance_id => $jobinstance_id, exitcode => $exit_code, msg => $error_message }); $sftp->disconnect;
      return $exit_code;
    }
  }

  # Connect to the target
  $sftp = Net::SFTP::Foreign->new( host => $target->{machine}->{ip}, user => $target->{credential}->{username}, password => $target->{credential}->{password} );
  if ( failProtocol({ 
    jobinstance_id => $jobinstance_id,
    error => $sftp->error, 
    error_message => "SFTP not enabled in ".$target->{machine}->{hostname}.", trying with FTP.", 
    ok_message => "SFTP connection established to ".$target->{machine}->{hostname}."." 
    }) ) {
    $sftp->disconnect;
    # If SFTP connection failed, let's try with FTP

    # Connect to target with FTP
    # Passive Mode set to 0 so it is not used. This is because for some servers Passive Mode does not work.
    my $ftp = Net::FTP->new( $target->{machine}->{ip}, Debug => 0, Passive => 0) or $status = 'FAILURE';
    
    if ( failProtocol({ 
      jobinstance_id => $jobinstance_id,
      error => $status eq 'FAILURE', 
      error_message => "Cannot connect to ".$target->{machine}->{hostname}." with FTP. Error Message: ".$@, 
      ok_message => "FTP connection established to ".$target->{machine}->{hostname}."." 
      }) ) {
      $exit_code = 6;
      exitProtocol({ jobinstance_id => $jobinstance_id, exitcode => $exit_code, msg => $error_message });
      return $exit_code;
    }

    # Login to the target with FTP
    $ftp->login( $target->{credential}->{username}, $target->{credential}->{password} ) or $status = 'FAILURE';
    if ( failProtocol({ 
      jobinstance_id => $jobinstance_id,
      error => $status eq 'FAILURE', 
      error_message => "Cannot login to ".$target->{machine}->{hostname}." with ".$target->{credential}->{username}.". Error Message: ".$ftp->message, 
      ok_message => "FTP login sucessful to ".$target->{machine}->{hostname}." with ".$target->{credential}->{username}."." 
      }) ) {
      $exit_code = 7;
      exitProtocol({ jobinstance_id => $jobinstance_id, exitcode => $exit_code, msg => $error_message }); $ftp->quit;
      return $exit_code;
    }

    if ($binary_ftp) {
      $ftp->binary;  
    } else {
      $ftp->ascii;
    }    

    # Put the file to the target with FTP
    $ftp->put( $tmp_file, $target->{file}->{name} ) or $status = 'FAILURE';
    if ( failProtocol({ 
      jobinstance_id => $jobinstance_id,
      error => $status eq 'FAILURE', 
      error_message => "Cannot put the file ".$target->{file}->{name}." to ".$target->{machine}->{hostname}." with ".$target->{credential}->{username}.". Error Message: ".$ftp->message, 
      ok_message => "File $tmp_file successfuly FTP transfered to ".$target->{credential}->{username}."@".$target->{machine}->{hostname}.":".$target->{file}->{name}."."
      }) ) {
      $exit_code = 8;
      exitProtocol({ jobinstance_id => $jobinstance_id, exitcode => $exit_code, msg => $error_message }); $ftp->quit;
      return $exit_code;
    }

    $ftp->quit;
    # Go to execute the PostActions

  } else {
    # SFTP is working, lets put the file.
    # Put the file into the target
    $sftp->put( $tmp_file, $target->{file}->{name} );
    if ( failProtocol({ 
      jobinstance_id => $jobinstance_id,
      error => $sftp->error, 
      error_message => "Cannot put the file ".$target->{file}->{name}." to ".$target->{machine}->{ip}.". Error: ".$sftp->error.". Status: ".$sftp->status, 
      ok_message => "File $tmp_file successfuly transfered to ".$target->{credential}->{username}."@".$target->{machine}->{hostname}.":".$target->{file}->{name}."." 
      }) ) {
      $exit_code = 4;
      exitProtocol({ jobinstance_id => $jobinstance_id, exitcode => $exit_code, msg => $error_message }); $sftp->disconnect;
      return $exit_code;
    }

    $sftp->disconnect;
    # Go to execute the PostActions
  }

  # Execute the PostActions
  my $jobinstance = findFirstOf('JobInstances', $jobinstance_id);
  my $results = executePostActions($jobinstance, $source->{file}->{name});
  if ( $results->{msgType} ne 'success' ) {
    $exit_code = 5;
    exitProtocol({ jobinstance_id => $jobinstance_id, exitcode => $exit_code, msg => $results->{message} });
  } else {
    $exit_code = 0;
    if ( $_[0]->{source_file} ) { # There are more files to transfer, do not finish the Job Instance
      updateJobInstance($jobinstance_id, { status => 'SUCCESS', results => $results->{message} });
    } else {
      updateJobInstance($jobinstance_id, { end_on => 1, status => 'SUCCESS', exit_code => $exit_code, results => $results->{message} });
    }
  }

  return $exit_code;
}

sub sftp_bin ($) {
  return sftp($_[0], 1);
}

sub sftp_ascii ($) {
  return sftp($_[0], 0);
}

sub scp ($) {
  my $source = getContainer $_[0]->{source};
  my $target = getContainer $_[0]->{target};
  my $jobinstance_id      = $_[0]->{jobinstance_id};

  if ( $_[0]->{source_file} ) {
    $source->{file}->{name} = $_[0]->{source_file};
    my ($filename, $directories, $suffix) = fileparse( $source->{file}->{name} );
    $target->{file}->{name} = $target->{file}->{name}."/".$filename;
  }
    

  return 999 if isOpen( $source, $jobinstance_id );

  my $msg;
  my @status     = 'success';
  my $tmp_file   = getTmpFilename( $jobinstance_id, $source->{file}->{name} );
  my $status     = 'STARTING';
  my $exit_code  = 0;

  # Getting the file from source
  my $scp = Net::SCP->new( { host => $source->{machine}->{ip}, user => $source->{credential}->{username} } );
  $scp->get( $source->{file}->{name}, $tmp_file );

  $status = $scp->{errstr} ? 'FAILURE' : 'RUNNING';
  $msg = $scp->{errstr} || "File ".$source->{credential}->{username}."@".$source->{machine}->{ip}.":".$source->{file}->{name}." successfuly transfered to ypFTG server.";
  # my $status_id = getStatusID( $status );  
  updateJobInstance($jobinstance_id, { status => $status, results => $msg });

  # If successful send the file to target
  if ( $status eq 'RUNNING' ) {
    $scp = Net::SCP->new( { host => $target->{machine}->{ip}, user => $target->{credential}->{username} } );
    $scp->put( $tmp_file, $target->{file}->{name} );
    
    $status = $scp->{errstr} ? 'FAILURE' : 'SUCCESS';
    $msg = $scp->{errstr} || "File successfuly transfered to ".$target->{credential}->{username}."@".$target->{machine}->{ip}.":".$target->{file}->{name}.".";
    # $status_id = getStatusID( $status );
    updateJobInstance($jobinstance_id, { status => $status, results => $msg });
  } else {
    $exit_code = 2;
  }

  # If failed in any of the previous steps
  # If failed because of the GET then exit_code is 1. If failed because of the PUT the exit_code is 2
  if ( $status eq 'FAILURE' and $exit_code == 0 ) {
    $exit_code = 1;
    $msg = "File ".$source->{credential}->{username}."@".$source->{machine}->{ip}.":".$source->{file}->{name}." was not transfered to ".$target->{credential}->{username}."@".$target->{machine}->{ip}.":".$target->{file}->{name}.".";
    # $status_id = getStatusID( $status ); 
    updateJobInstance($jobinstance_id, { end_on => 1, status => $status, exit_code => $exit_code, results => $msg });
  }

  if ( $exit_code == 0 ) {
    # Execute the PostActions
    my $jobinstance = findFirstOf('JobInstances', $jobinstance_id);
    my $results = executePostActions($jobinstance, $source->{file}->{name});
    if ( $results->{msgType} ne 'success' ) {
      $exit_code = 5;
      exitProtocol({ jobinstance_id => $jobinstance_id, exitcode => $exit_code, msg => $results->{message} });
    } else {
      $exit_code = 0;
      if ( $_[0]->{source_file} ) { # There are more files to transfer, do not finish the Job Instance
        updateJobInstance($jobinstance_id, { status => 'SUCCESS', results => $results->{message} });
      } else {
        updateJobInstance($jobinstance_id, { end_on => 1, status => 'SUCCESS', exit_code => $exit_code, results => $results->{message} });
      }
    }
  }

  $scp->quit;
  undef $scp;

  return $exit_code;
}

1;