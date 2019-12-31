package Controllers::Contacts;

use strict;
use warnings;

use Dancer ':syntax';
use Dancer::Plugin::Database;
use Dancer::Plugin::FlashMessage;
use Controller qw(findAllOf findFirstOf intoDB);

=pod

=cut

sub stats () {
  my $total = database->quick_count('Contacts', {});
  return { total => $total }
}

sub create_update ($) {
  return 0 if ! Controller::amIAdmin;
  my $params = shift;
  return intoDB( 'Contacts', $params );
}

# GET /contacts
# List all the Contacts
sub index () {
  my @contacts = findAllOf( 'Contacts' );
  foreach my $contact (@contacts) {
    my $team = findFirstOf('Teams', $contact->{team_id});
    $contact->{team} = $team->{name}." (".$team->{email}.")";
  }
  return { contacts => \@contacts, pager => Controller::pager(scalar @contacts, param( 'per' ), param( 'cur' )) };
}

# GET /contacts/new
# Render a form to create a new Contact
sub new () {
  return { error => "You need to be Admin to create a new Contact." } if ! Controller::amIAdmin;
  my @teams = findAllOf('Teams');
  return { teams => \@teams };
}

# POST /contacts
# Insert/Create a new Contact with the data provided from the create form.
sub create ($) {
  return { error => "You need to be Admin to create this Contact." } if ! Controller::amIAdmin;
  my $params = shift;
  if ( create_update( $params ) ) {
    flash success => "Contact '".$params->{firstname}." ".$params->{lastname}."' sucessfuly created/updated.";
  } else {
    flash error => "Something happen, the Contact '".$params->{firstname}." ".$params->{lastname}."' could not be created/upated.";
  }; 
}

# GET /contacts/1/edit
# Render a Contact data in a form to be updated.
sub edit ($) {
  return { error => "You need to be Admin to edit this Contact." } if ! Controller::amIAdmin;
  my $params = shift;
  my $id = $params->{id};

  my $contact = findFirstOf( 'Contacts', $id );
  my @teams = findAllOf('Teams');
  return { contact => $contact, teams => \@teams }
}

# POST /contacts/1
# Update a Contact with the data provided from the edit form.
# TODO: Should be used PUT insted of POST but it cannot be in a form. Need to find a way to send a PUT request.
sub update ($) {
  return { error => "You need to be Admin to update this Contact." } if ! Controller::amIAdmin;
  my $params = shift;
  if ( create_update( $params ) ) {
    flash success => "Contact '".$params->{firstname}." ".$params->{lastname}."' sucessfuly created/updated.";
  } else {
    flash error => "Something happen, the Contact '".$params->{firstname}." ".$params->{lastname}."' could not be created/upated.";
  }; 
}

# GET /contacts/1
# Render one Contact
sub show ($) {
  my $params = shift;

  my $contact = findFirstOf( 'Contacts', $params->{id} );
  my $team = findFirstOf('Teams', $contact->{team_id});

  my $user = database->quick_select('Users', { contact_id => $params->{id}  });
  my $username = $user ? $user->{username} : 'NONE';

  my @credentials = database->quick_select('Credentials', { contact_id => $contact->{id} });
  my @jobs = database->quick_select('Jobs', { contact_id => $contact->{id} });
  return { contact => $contact, team => $team, username => $username, credentials => \@credentials, jobs => \@jobs }
}

true;