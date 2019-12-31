package Controllers::Admin::Roles;

use strict;
use warnings;

use Dancer ':syntax';
use Dancer::Plugin::Database;
use Dancer::Plugin::FlashMessage;
use Controller qw(findAllOf findFirstOf intoDB amIAdmin);

use Crypt::SaltedHash;

=pod

=cut

my @ROLES = qw(Admin Guest User);

sub get_role_name ($) {
  my $role_id = shift;
  debug "Role ID: |$role_id|";
  return $ROLES[$role_id - 1];
}

sub stats () {
  return {} if ! amIAdmin;
  my $total = database->quick_count('Roles', {});
  return { total => $total }
}

sub create_update ($) {
  return {} if ! amIAdmin;
  my $params = shift;
  return intoDB( 'Roles', $params );
}

# GET /roles
# List all the Roles
sub index () {
  return {} if ! amIAdmin;
  my @roles = findAllOf( 'Roles' );
  foreach my $role (@roles) {
    $role->{users_count} = database->quick_count('Users', { role_id => $role->{id} });
  }
  return { roles => \@roles, pager => Controller::pager(scalar @roles, param( 'per' ), param( 'cur' )) };
}

# GET /roles/new
# Render a form to create a new Role
sub new () {
  return {} if ! amIAdmin;
  return { };
}

# POST /roles
# Insert/Create a new Role with the data provided from the create form.
sub create ($) {
  return {} if ! amIAdmin;
  my $params = shift;
    if ( create_update( $params ) ) {
    flash success => "Role '".$params->{name}."' sucessfuly created/updated.";
  } else {
    flash error => "Something happen, the Role '".$params->{name}."' could not be created/upated.";
  }; 
}

# GET /roles/1/edit
# Render a Role data in a form to be updated.
sub edit ($) {
  return {} if ! amIAdmin;
  my $params = shift;
  my $id = $params->{id};

  my $role = findFirstOf( 'Roles', $id );
  return { arole => $role }
}

# POST /roles/1
# Update a Role with the data provided from the edit form.
# TODO: Should be used PUT insted of POST but it cannot be in a form. Need to find a way to send a PUT request.
sub update ($) {
  return {} if ! amIAdmin;
  my $params = shift;
    if ( create_update( $params ) ) {
    flash success => "Role '".$params->{name}."' sucessfuly created/updated.";
  } else {
    flash error => "Something happen, the Role '".$params->{name}."' could not be created/upated.";
  }; 
}

# GET /roles/1
# Render one Role
sub show ($) {
  return {} if ! amIAdmin;
  my $params = shift;

  my $role = findFirstOf( 'Roles', $params->{id} );
  my @users = database->quick_select('Users', { role_id => $role->{id} });

  return { arole => $role, users => \@users }
}

true;