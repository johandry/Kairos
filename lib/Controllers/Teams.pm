package Controllers::Teams;

use strict;
use warnings;

use Dancer ':syntax';
use Dancer::Plugin::Database;
use Dancer::Plugin::FlashMessage;
use Controller qw(findAllOf findFirstOf intoDB);

=pod

=cut

sub create_update ($) {
  return 0 if ! Controller::amIAdmin;
  my $params = shift;
  return intoDB( 'Teams', $params );
}

# GET /teams
# List all the Teams
sub index () {
  my @teams = findAllOf('Teams');
  return { teams => \@teams, pager => Controller::pager(scalar @teams, param( 'per' ), param( 'cur' )) }
}

# GET /teams/new
# Render a form to create a new Team
sub new () {
  return { error => "You need to be Admin to create a new Team." } if ! Controller::amIAdmin;
  return { }
}

# POST /teams
# Insert/Create a new Team with the data provided from the create form.
sub create ($) {
  return { error => "You need to be Admin to create this Team." } if ! Controller::amIAdmin;
  my $params = shift;

  if ( create_update( $params ) ) {
    flash success => "Team or Vendor '".$params->{name}."' sucessfuly created/updated.";
  } else {
    flash error => "Something happen, the Team or Vendor '".$params->{name}."' could not be created/upated.";
  };  
}

# GET /teams/1/edit
# Render a Team data in a form to be updated.
sub edit ($) {
  return { error => "You need to be Admin to edit this Team." } if ! Controller::amIAdmin;
  my $params = shift;
  my $id = $params->{id};

  my $team = findFirstOf('Teams', $id);
  return { team => $team }
}

# POST /teams/1
# Update a Team with the data provided from the edit form.
# TODO: Should be used PUT insted of POST but it cannot be in a form. Need to find a way to send a PUT request.
sub update ($) {
  return { error => "You need to be Admin to udpate this Team." } if ! Controller::amIAdmin;
  my $params = shift;

  if ( create_update( $params ) ) {
    flash success => "Team or Vendor '".$params->{name}."' sucessfuly updated.";
  } else {
    flash error => "Something happen, the Team or Vendor '".$params->{name}."' could not be updated.";
  }; 
}

# GET /teams/1
# Render one Team
sub show ($) {
  my $params = shift;

  my $team = findFirstOf('Teams', $params->{id});

  my @contacts = database->quick_select('Contacts', { team_id => $team->{id} });
  return { team => $team, contacts => \@contacts }
}

true;