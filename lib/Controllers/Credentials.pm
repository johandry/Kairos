package Controllers::Credentials;

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
  return intoDB( 'Credentials', $params );
}

# GET /credentials
# List all the Credentials
sub index () {
  my @credentials = findAllOf('Credentials');
  foreach my $credential (@credentials) {
    my $contact = findFirstOf('Contacts', $credential->{contact_id} );
    $credential->{contact} = $contact->{firstname}." ".$contact->{lastname}." (".$contact->{email}.")";
  }
  return { credentials => \@credentials, pager => Controller::pager(scalar @credentials, param( 'per' ), param( 'cur' )) };
}

# GET /credentials/new
# Render a form to create a new Credential
sub new () {
  return { error => "You need to be Admin to create a new Credential." } if ! Controller::amIAdmin;
  my @contacts = findAllOf('Contacts');
  return { contacts => \@contacts };
}

# POST /credentials
# Insert/Create a new Credential with the data provided from the create form.
sub create ($) {
  return { error => "You need to be Admin to create this Credential." } if ! Controller::amIAdmin;
  my $params = shift;
    if ( create_update( $params ) ) {
    flash success => "Credential '".$params->{username}."' sucessfuly created/updated.";
  } else {
    flash error => "Something happen, the Credential '".$params->{username}."' could not be created/upated.";
  }; 
}

# GET /credentials/1/edit
# Render a Credential data in a form to be updated.
sub edit ($) {
  return { error => "You need to be Admin to edit this Credential." } if ! Controller::amIAdmin;
  my $params = shift;
  my $id = $params->{id};

  my $credential = findFirstOf('Credentials', $id);
  my @contacts = findAllOf('Contacts');
  return { credential => $credential, contacts => \@contacts }
}

# POST /credentials/1
# Update a Credential with the data provided from the edit form.
# TODO: Should be used PUT insted of POST but it cannot be in a form. Need to find a way to send a PUT request.
sub update ($) {
  return { error => "You need to be Admin to update this Credential." } if ! Controller::amIAdmin;
  my $params = shift;
    if ( create_update( $params ) ) {
    flash success => "Credential '".$params->{username}."' sucessfuly created/updated.";
  } else {
    flash error => "Something happen, the Credential '".$params->{username}."' could not be created/upated.";
  }; 
}

# GET /credentials/1
# Render one Credential
sub show ($) {
  my $params = shift;

  my $credential = findFirstOf('Credentials', $params->{id});
  my $contact = findFirstOf('Contacts', $credential->{contact_id});
  my $team = findFirstOf('Teams', $contact->{team_id});

  my @containers = database->quick_select('Containers', { credential_id => $credential->{id} });
  return { credential => $credential, contact => $contact, team => $team, containers => \@containers }
}

true;