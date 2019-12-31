package Controllers::Admin::Users;

use strict;
use warnings;

use Dancer ':syntax';
use Dancer::Plugin::Database;
use Dancer::Plugin::FlashMessage;
use Controller qw(findAllOf findFirstOf intoDB amIAdmin);

use Crypt::SaltedHash;

=pod

=cut

sub stats () {
  return {} if ! amIAdmin;
  my $total = database->quick_count('Users', {});
  return { total => $total }
}

sub create_update ($) {
  return {} if ! amIAdmin;
  my $params = shift;
  if ( $params->{password} ) {
    my $csh = Crypt::SaltedHash->new(algorithm => 'SHA-1');
    $csh->add($params->{password});
    $params->{password} = $csh->generate;
  }
  return intoDB( 'Users', $params );
}

# GET /users
# List all the Users
sub index () {
  return {} if ! amIAdmin;
  my @users = findAllOf( 'Users' );
  foreach my $user (@users) {
    my $role = findFirstOf('Roles', $user->{role_id});
    $user->{role} = $role->{name};
    my $contact = findFirstOf('Contacts', $user->{contact_id});
    $user->{contact} = $contact ? $contact->{firstname}." ".$contact->{firstname} : '';
    $user->{email} = $contact ? $contact->{email} : '';
  }
  return { users => \@users, pager => Controller::pager(scalar @users, param( 'per' ), param( 'cur' )) };
}

# GET /users/new
# Render a form to create a new User
sub new () {
  return {} if ! amIAdmin;
  my @roles = findAllOf('Roles');
  my @contacts = findAllOf('Contacts');
  return { roles => \@roles, contacts => \@contacts };
}

# POST /users
# Insert/Create a new User with the data provided from the create form.
sub create ($) {
  return {} if ! amIAdmin;
  my $params = shift;
  if ( create_update( $params ) ) {
    flash success => "User '".$params->{username}."' sucessfuly created/updated.";
  } else {
    flash error => "Something happen, the User '".$params->{username}."' could not be created/upated.";
  }; 
}

# GET /users/1/edit
# Render a User data in a form to be updated.
sub edit ($) {
  return {} if ! amIAdmin;
  my $params = shift;
  my $id = $params->{id};

  my $user = findFirstOf( 'Users', $id );
  my @roles = findAllOf('Roles');
  my @contacts = findAllOf('Contacts');
  return { user => $user, roles => \@roles, contacts => \@contacts }
}

# POST /users/1
# Update a User with the data provided from the edit form.
# TODO: Should be used PUT insted of POST but it cannot be in a form. Need to find a way to send a PUT request.
sub update ($) {
  return {} if ! amIAdmin;
  my $params = shift;
  if ( create_update( $params ) ) {
    flash success => "User '".$params->{username}."' sucessfuly created/updated.";
  } else {
    flash error => "Something happen, the User '".$params->{username}."' could not be created/upated.";
  }; 
}

# GET /users/1
# Render one User
sub show ($) {
  return {} if ! amIAdmin;
  my $params = shift;

  my $user = findFirstOf( 'Users', $params->{id} );
  my $role = findFirstOf('Roles', $user->{role_id});
  my $contact = findFirstOf('Contacts', $user->{contact_id});
  my $email = $contact ? $contact->{email} : '';
  $contact = $contact ? $contact->{firstname}." ".$contact->{lastname} : '';
  

  return { user => $user, arole => $role, contact => $contact, email => $email }
}

true;