package Controllers::Files;

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
  debug $params;
  return intoDB( 'Files', $params );
}

# GET /files
# List all the Files
sub index () {
  my @files = findAllOf('Files');
  return { files => \@files, pager => Controller::pager(scalar @files, param( 'per' ), param( 'cur' )) };
}

# GET /files/new
# Render a form to create a new File
sub new () {
  return { error => "You need to be Admin to create a new File." } if ! Controller::amIAdmin;
  return { }
}

# POST /files
# Insert/Create a new File with the data provided from the create form.
sub create ($) {
  return { error => "You need to be Admin to create this File." } if ! Controller::amIAdmin;
  my $params = shift;
  if ( create_update( $params ) ) {
    flash success => "File '".$params->{name}."' sucessfuly created/updated.";
  } else {
    flash error => "Something happen, the File '".$params->{name}."' could not be created/upated.";
  }; 
}

# GET /files/1/edit
# Render a File data in a form to be updated.
sub edit ($) {
  return { error => "You need to be Admin to edit this File." } if ! Controller::amIAdmin;
  my $params = shift;
  my $id = $params->{id};

  my $file = findFirstOf('Files', $id);
  return { file => $file }
}

# POST /files/1
# Update a File with the data provided from the edit form.
# TODO: Should be used PUT insted of POST but it cannot be in a form. Need to find a way to send a PUT request.
sub update ($) {
  return { error => "You need to be Admin to update this File." } if ! Controller::amIAdmin;
  my $params = shift;
    if ( create_update( $params ) ) {
    flash success => "File '".$params->{name}."' sucessfuly created/updated.";
  } else {
    flash error => "Something happen, the File '".$params->{name}."' could not be created/upated.";
  }; 
}

# GET /files/1
# Render one File
sub show ($) {
  my $params = shift;

  my $file = findFirstOf('Files', $params->{id});
  my $team = findFirstOf('Teams', $file->{team_id});

  my @containers = database->quick_select('Containers', { file_id => $file->{id} });
  return { file => $file, team => $team, containers => \@containers }
}

true;