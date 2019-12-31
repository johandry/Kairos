package Controllers::JobGroups;

use strict;
use warnings;

use Dancer ':syntax';
use Dancer::Plugin::Database;
use Dancer::Plugin::FlashMessage;
use Controller qw(findAllOf findFirstOf intoDB);

=pod

=cut

sub create_update ($) {
  my $params = shift;
  return 0 if ! Controller::amIAdmin;
  return intoDB( 'JobGroups', $params );
}

# GET /jobgroups
# List all the JobGroups
sub index () {
  my @jobgroups = findAllOf('JobGroups');
  return { jobgroups => \@jobgroups, pager => Controller::pager(scalar @jobgroups, param( 'per' ), param( 'cur' )) }
}

# GET /jobgroups/new
# Render a form to create a new Team
sub new () {
  return { error => "You need to be Admin to create a new JobGroup." } if ! Controller::amIAdmin;
  return { }
}

# POST /jobgroups
# Insert/Create a new Team with the data provided from the create form.
sub create ($) {
  return { error => "You need to be Admin to create this JobGroup." } if ! Controller::amIAdmin;
  my $params = shift;

  if ( create_update( $params ) ) {
    flash success => "JobGroup '".$params->{name}."' sucessfuly created/updated.";
  } else {
    flash error => "Something happen, the JobGroup '".$params->{name}."' could not be created/upated.";
  };  
}

# GET /jobgroups/1/edit
# Render a Team data in a form to be updated.
sub edit ($) {
  return { error => "You need to be Admin to edit this JobGroup." } if ! Controller::amIAdmin;
  my $params = shift;
  my $id = $params->{id};

  my $jobgroup = findFirstOf('JobGroups', $id);
  return { jobgroup => $jobgroup }
}

# POST /jobgroups/1
# Update a Team with the data provided from the edit form.
# TODO: Should be used PUT insted of POST but it cannot be in a form. Need to find a way to send a PUT request.
sub update ($) {
  return { error => "You need to be Admin to update this JobGroup." } if ! Controller::amIAdmin;
  my $params = shift;

  if ( create_update( $params ) ) {
    flash success => "JobGroup '".$params->{name}."' sucessfuly updated.";
  } else {
    flash error => "Something happen, the JobGroup '".$params->{name}."' could not be updated.";
  }; 
}

# GET /jobgroups/1
# Render one Team
sub show ($) {
  my $params = shift;

  my $jobgroup = findFirstOf('JobGroups', $params->{id});

  my @jobs = database->quick_select('Jobs', { group_id => $jobgroup->{id} });
  return { jobgroup => $jobgroup, jobs => \@jobs }
}

true;