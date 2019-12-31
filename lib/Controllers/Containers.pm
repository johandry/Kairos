package Controllers::Containers;

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

  my $credential_username = $ { database->quick_select('Credentials', { id => params->{credential_id} }, { columns => ['username'] }) }{username};
  my $machine_hostname = $ { database->quick_select('Machines', { id => params->{machine_id} }, { columns => ['hostname'] }) }{hostname};
  my $file_name = $ { database->quick_select('Files', { id => params->{file_id} }, { columns => ['name'] }) }{name};

  $params->{name} = "$credential_username\@$machine_hostname:$file_name";
  return intoDB( 'Containers', $params );
}

# GET /containers
# List all the Containers
sub index () {
  my @containers = findAllOf( 'Containers' );
  return { containers => \@containers, pager => Controller::pager(scalar @containers, param( 'per' ), param( 'cur' )) };
}

# GET /containers/new
# Render a form to create a new Container
sub new () {
  return { error => "You need to be Admin to create a new Container." } if ! Controller::amIAdmin;
  my @files = findAllOf('Files');
  my @machines = findAllOf('Machines');
  my @credentials = findAllOf('Credentials');
  return { files => \@files, machines  => \@machines, credentials => \@credentials };
}

# POST /containers
# Insert/Create a new Container with the data provided from the create form.
sub create ($) {
  return { error => "You need to be Admin to create this Container." } if ! Controller::amIAdmin;
  my $params = shift;
    if ( create_update( $params ) ) {
    flash success => "Container '".$params->{name}."' sucessfuly created/updated.";
    $params->{name} =~ /^(.*):.*$/;
    flash info    => "If you want non-password authentication to '".$1."' send the public key executing this command: ./bin/FTG.sh -A";
  } else {
    flash error => "Something happen, the Container '".$params->{name}."' could not be created/upated.";
  }; 
}

# GET /containers/1/edit
# Render a Container data in a form to be updated.
sub edit ($) {
  return { error => "You need to be Admin to edit this Container." } if ! Controller::amIAdmin;
  my $params = shift;
  my $id = $params->{id};

  my $container = findFirstOf( 'Containers', $id);
  my @files = findAllOf('Files');
  my @machines = findAllOf('Machines');
  my @credentials = findAllOf('Credentials');
  return { container => $container, files => \@files, machines  => \@machines, credentials => \@credentials }
}

# POST /containers/1
# Update a Container with the data provided from the edit form.
# TODO: Should be used PUT insted of POST but it cannot be in a form. Need to find a way to send a PUT request.
sub update ($) {
  return { error => "You need to be Admin to update this Container." } if ! Controller::amIAdmin;
  my $params = shift;
    if ( create_update( $params ) ) {
    flash success => "Container '".$params->{name}."' sucessfuly created/updated.";
  } else {
    flash error => "Something happen, the Container '".$params->{name}."' could not be created/upated.";
  }; 
}

# GET /containers/1
# Render one Container
sub show ($) {
  my $params = shift;

  my $container = findFirstOf( 'Containers', params->{id} );
  my $credential = findFirstOf('Credentials', $container->{credential_id} );
  my $credential_contact = findFirstOf('Contacts', $credential->{contact_id} );
  $credential->{contact_name} = $credential_contact->{firstname}." ".$credential_contact->{lastname}." (".$credential_contact->{email}.")";
  my $machine = findFirstOf('Machines', $container->{machine_id} );
  $machine->{dc_name} = database->quick_lookup('Datacenters', { id => $machine->{dc_id} }, 'name');
  my $file = findFirstOf('Files', $container->{file_id} );

  my @filetransfers_source = database->quick_select('Filetransfers', { source_id => $container->{id} });
  my @filetransfers_target = database->quick_select('Filetransfers', { target_id => $container->{id} });
  my @filetransfers = (@filetransfers_source, @filetransfers_target);

  my @commands = database->quick_select('Commands', { container_id => $container->{id} });

  return { container => $container, credential => $credential, machine => $machine, file => $file, filetransfers => \@filetransfers, commands => \@commands }
}

true;