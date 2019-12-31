package Controllers::Conditions;

use strict;
use warnings;

use Dancer ':syntax';
use Dancer::Plugin::Database;
use Dancer::Plugin::FlashMessage;
use Controller qw(findAllOf findFirstOf intoDB);

=pod

=cut

sub check ($) {
  my $condition = shift;

  return { msgType => 'success', message => 'Condition is true.' };
}

sub create_update ($) {
  my $params = shift;
  return 0 if ! Controller::amIAdmin;

  my $status_shortname = ${ database->quick_select('Statuses',   { id => $params->{status_id} },    { colums => ['shortname'] }) }{shortname};
  my $job_name         = ${ database->quick_select('Jobs',       { id => $params->{job_id}  },      { colums => ['name'] }) }{name};
  my $schedule_name    = ${ database->quick_select('Schedules',  { id => $params->{schedule_id}  }, { colums => ['name'] }) }{name};
  $params->{name} = "$status_shortname($job_name)#$schedule_name";

  return intoDB( 'Conditions', $params );
}

# GET /conditions
# List all the Conditions
sub index () {
  my @conditions = findAllOf('Conditions');

  foreach my $condition (@conditions) {
    $condition->{status}   = ${ database->quick_select('Statuses',  { id => $condition->{status_id} },   { colums => ['name'] }) }{name};
    $condition->{job}      = ${ database->quick_select('Jobs',      { id => $condition->{job_id} },      { colums => ['name'] }) }{name};
    $condition->{schedule} = ${ database->quick_select('Schedules', { id => $condition->{schedule_id} }, { colums => ['name'] }) }{name};
  }
  return { conditions => \@conditions, pager => Controller::pager(scalar @conditions, param( 'per' ), param( 'cur' )) };
}

# GET /conditions/new
# Render a form to create a new Condition
sub new () {
  return { error => "You need to be Admin to create a new Condition." } if ! Controller::amIAdmin;
  my @statuses  = findAllOf('Statuses');
  my @jobs      = findAllOf('Jobs');
  my @schedules = findAllOf('Schedules');

  return { statuses => \@statuses, jobs => \@jobs, schedules => \@schedules }
}

# POST /conditions
# Insert/Create a new Condition with the data provided from the create form.
sub create ($) {
  return { error => "You need to be Admin to create this Condition." } if ! Controller::amIAdmin;
  my $params = shift;
    if ( create_update( $params ) ) {
    flash success => "Condition '".$params->{name}."' sucessfuly created/updated.";
  } else {
    flash error => "Something happen, the Condition '".$params->{name}."' could not be created/upated.";
  }; 
}

# GET /conditions/1/edit
# Render a Condition data in a form to be updated.
sub edit ($) {
  return { error => "You need to be Admin to edit this Condition." } if ! Controller::amIAdmin;
  my $params = shift;
  my $id = $params->{id};

  my $condition = findFirstOf('Conditions', $id);
  my @statuses  = findAllOf('Statuses');
  my @jobs      = findAllOf('Jobs');
  my @schedules = findAllOf('Schedules');

  return { condition => $condition, statuses => \@statuses, jobs => \@jobs, schedules => \@schedules }
}

# POST /conditions/1
# Update a Condition with the data provided from the edit form.
# TODO: Should be used PUT insted of POST but it cannot be in a form. Need to find a way to send a PUT request.
sub update ($) {
  return { error => "You need to be Admin to update this Condition." } if ! Controller::amIAdmin;
  my $params = shift;
    if ( create_update( $params ) ) {
    flash success => "Condition '".$params->{name}."' sucessfuly created/updated.";
  } else {
    flash error => "Something happen, the Condition '".$params->{name}."' could not be created/upated.";
  }; 
}

# GET /conditions/1
# Render one Condition
sub show ($) {
  my $params = shift;

  my $condition = findFirstOf('Conditions',   $params->{id});
  my $status    = findFirstOf('Statuses',     $condition->{status_id});
  my $job       = findFirstOf('Jobs',         $condition->{job_id});
  my $action    = findFirstOf('Filetransfers',$job->{action_id});
  my $owner     = findFirstOf('Contacts',     $job->{contact_id});
  my $schedule  = findFirstOf('Schedules',    $condition->{schedule_id}); 

  my $condition_type_id = ${ database->quick_select('Triggers', { name => 'Condition' }, { colums => ['id'] }) }{id};
  my @jobs = database->quick_select('Jobs', { trigger_type => $condition_type_id, trigger_id => $condition->{id} });

  return { condition => $condition, status => $status, job => $job, action => $action, owner => $owner, schedule =>$schedule, jobs => \@jobs }
}

true;