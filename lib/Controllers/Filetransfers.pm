package Controllers::Filetransfers;

use strict;
use warnings;

use Dancer ':syntax';
use Dancer::Plugin::Database;
use Dancer::Plugin::FlashMessage;
use Controller qw(findAllOf findFirstOf intoDB);

=pod

=cut

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

  my $source_name   = $ { database->quick_select('Containers', { id => $params->{source_id} },   { columns => ['name'] }) }{name};
  my $target_name   = $ { database->quick_select('Containers', { id => $params->{target_id} },   { columns => ['name'] }) }{name};
  my $protocol_name = $ { database->quick_select('Protocols',  { id => $params->{protocol_id} }, { columns => ['name'] }) }{name};
  $params->{name} = "$source_name>$protocol_name>$target_name";

  return intoDB( 'Filetransfers', $params );
}

# GET /filetransfers
# List all the Filetransfers
sub index () {
  my @filetransfers = findAllOf('Filetransfers');
  return { filetransfers => \@filetransfers, pager => Controller::pager(scalar @filetransfers, param( 'per' ), param( 'cur' )) };
};

# GET /filetransfers/new
# Render a form to create a new Filetransfer
sub new () {
  return { error => "You need to be Admin to create a new Filetransfer." } if ! Controller::amIAdmin;
  my @containers = findAllContainersOfType('F');
  my @protocols = findAllOf('Protocols');
  return { containers => \@containers, protocols => \@protocols }
};

# POST /filetransfers
# Insert/Create a new Filetransfer with the data provided from the create form.
sub create ($) {
  return { error => "You need to be Admin to create this Filetransfer." } if ! Controller::amIAdmin;
  my $params = shift;
    if ( create_update( $params ) ) {
    flash success => "Filetransfer '".$params->{name}."' sucessfuly created/updated.";
  } else {
    flash error => "Something happen, the Filetransfer '".$params->{name}."' could not be created/upated.";
  }; 
}

# GET /filetransfers/1/edit
# Render a Filetransfer data in a form to be updated.
sub edit ($) {
  return { error => "You need to be Admin to edit this Filetransfer." } if ! Controller::amIAdmin;
  my $params = shift;
  my $id = $params->{id};

  my $filetransfer = findFirstOf('Filetransfers', $id);
  my @containers = findAllContainersOfType('F');
  my @protocols = findAllOf('Protocols');
  return { filetransfer => $filetransfer, containers => \@containers, protocols => \@protocols }
};

# POST /filetransfers/1
# Update a Filetransfer with the data provided from the edit form.
# TODO: Should be used PUT insted of POST but it cannot be in a form. Need to find a way to send a PUT request.
sub update ($) {
  return { error => "You need to be Admin to update this Filetransfer." } if ! Controller::amIAdmin;
  my $params = shift;
    if ( create_update( $params ) ) {
    flash success => "Filetransfer '".$params->{name}."' sucessfuly created/updated.";
  } else {
    flash error => "Something happen, the Filetransfer '".$params->{name}."' could not be created/upated.";
  }; 
}

# GET /filetransfers/1
# Render one Filetransfer
sub show ($) {
  my $params = shift;

  my $filetransfer = findFirstOf('Filetransfers', $params->{id});
  my $source = findFirstOf('Containers', $filetransfer->{source_id});
  $source->{file_name} = $ { database->quick_select('Files', { id => $source->{file_id} }, { columns => ['name'] }) }{name};
  my $machine = database->quick_select('Machines', { id => $source->{machine_id} }, { columns => ['hostname', 'domainname'] });
  $source->{machine_hostname} = $machine->{hostname}.".".$machine->{domainname};
  $source->{credential_username} = $ { database->quick_select('Credentials', { id => $source->{credential_id} }, { columns => ['username'] }) }{username};
  my $target = findFirstOf('Containers', $filetransfer->{target_id});
  $target->{file_name} = $ { database->quick_select('Files', { id => $target->{file_id} }, { columns => ['name'] }) }{name};
  $machine = database->quick_select('Machines', { id => $target->{machine_id} }, { columns => ['hostname', 'domainname'] });
  $target->{machine_hostname} = $machine->{hostname}.".".$machine->{domainname};
  $target->{credential_username} = $ { database->quick_select('Credentials', { id => $target->{credential_id} }, { columns => ['username'] }) }{username};  
  my $protocol = findFirstOf('Protocols', $filetransfer->{protocol_id});

  my $action_type = ${database->quick_select('Actions', {name => 'Filetransfer'}, { columns => ['id'] })}{id};
  my @jobs = database->quick_select('Jobs', { action_type => $action_type, action_id => $filetransfer->{id} });
  return { 
    filetransfer => $filetransfer,
    source => $source,
    target => $target,
    protocol => $protocol,
    jobs => \@jobs,
  }
}

true;