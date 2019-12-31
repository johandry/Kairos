package Controllers::Commands;

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
  my $params = shift;
  return 0 if ! Controller::amIAdmin;

  return intoDB( 'Commands', $params );
}

# GET /commands
# List all the Commands
sub index () {
  my @commands = findAllOf('Commands');
  foreach my $command (@commands) {
    my $parameters = $command->{parameters} // '';
    $command->{command} = database->quick_lookup( 'Containers', { id => $command->{container_id} }, 'name')." ".$parameters;
    $command->{type_name} = database->quick_lookup('CommandTypes', { id => $command->{type} }, 'name');
  }
  return { commands => \@commands, pager => Controller::pager(scalar @commands, param( 'per' ), param( 'cur' )) };
};

# GET /commands/new
# Render a form to create a new Command
sub new () {
  return { error => "You need to be Admin to create a new Command." } if ! Controller::amIAdmin;
  my @containers = findAllContainersOfType('S');
  my @types = findAllOf('CommandTypes');

  return { containers => \@containers, types => \@types }
};

# POST /commands
# Insert/Create a new Command with the data provided from the create form.
sub create ($) {
  return { error => "You need to be Admin to create this Command." } if ! Controller::amIAdmin;
  my $params = shift;
    if ( create_update( $params ) ) {
    flash success => "Command '".$params->{name}."' sucessfuly created/updated.";
  } else {
    flash error => "Something happen, the Command '".$params->{name}."' could not be created/upated.";
  }; 
}

# GET /commands/1/edit
# Render a Command data in a form to be updated.
sub edit ($) {
  return { error => "You need to be Admin to edit this Command." } if ! Controller::amIAdmin;
  my $params = shift;
  my $id = $params->{id};

  my $command = findFirstOf('Commands', $id);
  my @containers = findAllContainersOfType('S'); 
  my @types = findAllOf('CommandTypes');

  return { command => $command, containers => \@containers, types => \@types }
};

# POST /commands/1
# Update a Command with the data provided from the edit form.
# TODO: Should be used PUT insted of POST but it cannot be in a form. Need to find a way to send a PUT request.
sub update ($) {
  return { error => "You need to be Admin to update this Command." } if ! Controller::amIAdmin;
  my $params = shift;
    if ( create_update( $params ) ) {
    flash success => "Command '".$params->{name}."' sucessfuly created/updated.";
  } else {
    flash error => "Something happen, the Command '".$params->{name}."' could not be created/upated.";
  }; 
}

# GET /commands/1
# Render one Command
sub show ($) {
  my $params = shift;

  my $command = findFirstOf('Commands', $params->{id});
  my $container = findFirstOf('Containers', $command->{container_id});
  $container->{file_name} = $ { database->quick_select('Files', { id => $container->{file_id} }, { columns => ['name'] }) }{name};
  my $machine = database->quick_select('Machines', { id => $container->{machine_id} }, { columns => ['hostname', 'domainname'] });
  $container->{machine_hostname} = $machine->{hostname}.".".$machine->{domainname};
  $container->{credential_username} = $ { database->quick_select('Credentials', { id => $container->{credential_id} }, { columns => ['username'] }) }{username};

  my $type = findFirstOf('CommandTypes', $command->{type});
  $command->{type_name} = $type->{name};

  my $action_type = ${database->quick_select('Actions', {name => 'Command'}, { columns => ['id'] })}{id};
  my @jobs = database->quick_select('Jobs', { action_type => $action_type, action_id => $command->{id} });

  my $preActionId = ${database->quick_select('CommandTypes', { name => 'Pre Action' })}{id};
  my @preActions = database->quick_select('JobsCommands', { command_id => $command->{id}, type => $preActionId });
  foreach my $preAction (@preActions) {
    my $job = findFirstOf('Jobs', $preAction->{job_id});
    $preAction->{job} = $job->{name};
  }
  my $postActionId = ${database->quick_select('CommandTypes', { name => 'Post Action' })}{id};
  my @postActions = database->quick_select('JobsCommands', { command_id => $command->{id}, type => $postActionId });
  foreach my $postAction (@postActions) {
    my $job = findFirstOf('Jobs', $postAction->{job_id});
    $postAction->{job} = $job->{name};
  }  

  return { 
    command => $command,
    container => $container,
    jobs => \@jobs,
    pre_actions => \@preActions,
    post_actions => \@postActions,
  }
}

true;