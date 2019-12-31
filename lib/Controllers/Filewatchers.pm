package Controllers::Filewatchers;

use strict;
use warnings;

use Dancer ':syntax';
use Dancer::Plugin::Database;
use Dancer::Plugin::FlashMessage;
use Controller qw(findAllOf findFirstOf intoDB);

=pod

=cut

sub execute ($$) {
  my $params = shift;
  my $cli    = shift;
  my $id     = $params->{id};

  my $filewatcher = findFirstOf('Filewatchers', $id); 
  my $filewatcher_type_id = ${ database->quick_select('Triggers', { name => 'Filewatcher' }, { colums => ['id'] }) }{id};
  my @jobs = database->quick_select('Jobs', { trigger_type => $filewatcher_type_id, trigger_id => $id });

  my @results;
  my $checkResult = check($filewatcher);
  push @results, $checkResult;
  print "[".scalar localtime(time)."] - FW  - $filewatcher->{id} - RUNNING - Files to watch were checked. ". ucfirst $checkResult->{msgType}.": $checkResult->{message}. At ".__FILE__." line ".__LINE__.".\n" if $cli;
  # info  "[".scalar localtime(time)."] - FW  - $filewatcher->{id} -  - Files to watch were checked. ". ucfirst $checkResult->{msgType}.": $checkResult->{message}.\n";
  if ($checkResult->{msgType} eq 'success') {
    foreach my $job (@jobs) {
      # print "Active: '$job->{active}'\n";
      if ( $job->{active} == 1 ) {      
        print "[".scalar localtime(time)."] - JOB - $job->{id} - STARTING - Executing Job $job->{name}. At ".__FILE__." line ".__LINE__.".\n" if $cli;
        push @results, Controllers::Jobs::execute( { id => $job->{id} }, 1, $cli);
        print "[".scalar localtime(time)."] - JOB - $job->{id} - END - Executing Job $job->{name}. At ".__FILE__." line ".__LINE__.".\n" if $cli;
      }
    }  
  } 
  return \@results;
}

sub check ($) {
  my $filewatcher = shift;

  my $container = database->quick_select('Containers', { id => $filewatcher->{container_id} });
  return Protocols::existsFile( $container );
}

sub findAllContainersOfType ($) {
  my $type = shift;
  my @containers = findAllOf('Containers');
  foreach my $container (@containers) {
    my $file = findFirstOf('Files', $container->{file_id});
    $container = undef if ($file->{type} ne $type);
  }
  @containers = grep defined, @containers; 
  return @containers;
}

sub create_update ($) {
  return 0 if ! Controller::amIAdmin;
  my $params = shift;

  my $container_name = ${ database->quick_select('Containers', { id => $params->{container_id} }, { colums => ['name'] }) }{name};
  my $schedule_name  = ${ database->quick_select('Schedules',  { id => $params->{schedule_id}  }, { colums => ['name'] }) }{name};
  $params->{name} = "$container_name#$schedule_name";

  return intoDB( 'Filewatchers', $params );
}

# GET /filewatchers
# List all the Filewatchers
sub index () {
  my @filewatchers = findAllOf('Filewatchers');
  return { filewatchers => \@filewatchers, pager => Controller::pager(scalar @filewatchers, param( 'per' ), param( 'cur' )) };
}

# GET /filewatchers/new
# Render a form to create a new Filewatcher
sub new () {
  return { error => "You need to be Admin to create a new Filewatcher." } if ! Controller::amIAdmin;
  my @containers = findAllContainersOfType('F');
  my @schedules = findAllOf('Schedules');

  return { containers => \@containers, schedules => \@schedules }

}

# POST /filewatchers
# Insert/Create a new Filewatcher with the data provided from the create form.
sub create ($) {
  return { error => "You need to be Admin to create this Filewatcher." } if ! Controller::amIAdmin;
  my $params = shift;
    if ( create_update( $params ) ) {
    flash success => "Filewatcher '".$params->{name}."' sucessfuly created/updated.";
  } else {
    flash error => "Something happen, the Filewatcher '".$params->{name}."' could not be created/upated.";
  }; 
}

# GET /filewatchers/1/edit
# Render a Filewatcher data in a form to be updated.
sub edit ($) {
  return { error => "You need to be Admin to edit this Filewatcher." } if ! Controller::amIAdmin;
  my $params = shift;
  my $id = $params->{id};

  my $filewatcher = findFirstOf('Filewatchers', $id);
  my @containers = findAllContainersOfType('F');
  my @schedules = findAllOf('Schedules');

  return { filewatcher => $filewatcher, containers => \@containers, schedules => \@schedules }
}

# POST /filewatchers/1
# Update a Filewatcher with the data provided from the edit form.
# TODO: Should be used PUT insted of POST but it cannot be in a form. Need to find a way to send a PUT request.
sub update ($) {
  return { error => "You need to be Admin to update this Filewatcher." } if ! Controller::amIAdmin;
  my $params = shift;
    if ( create_update( $params ) ) {
    flash success => "Filewatcher '".$params->{name}."' sucessfuly created/updated.";
  } else {
    flash error => "Something happen, the Filewatcher '".$params->{name}."' could not be created/upated.";
  }; 
}

# GET /filewatchers/1
# Render one Filewatcher
sub show ($) {
  my $params = shift;

  my $filewatcher = findFirstOf('Filewatchers', $params->{id});
  my $container = findFirstOf('Containers', $filewatcher->{container_id});
  my $schedule = findFirstOf('Schedules', $filewatcher->{schedule_id});

  my $filewatcher_type_id = ${ database->quick_select('Triggers', { name => 'Filewatcher' }, { colums => ['id'] }) }{id};
  my @jobs = database->quick_select('Jobs', { trigger_type => $filewatcher_type_id, trigger_id => $filewatcher->{id} });

  return { filewatcher => $filewatcher, container => $container, schedule =>$schedule, jobs => \@jobs }
}

true;