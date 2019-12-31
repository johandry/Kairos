package Controllers::Machines;

use strict;
use warnings;

use Dancer ':syntax';
use Dancer::Plugin::Database;
use Dancer::Plugin::FlashMessage;
use LWP::Simple ();
use Net::Domain;
use Socket;
use Controller qw(findAllOf findFirstOf intoDB);

=pod

=cut

sub machineNagiosStatus ($) {
  my $machine = shift;
  my $cred='doxtg:D0xt6';
  my $STAT_URL = "http://$cred\@fltva076.ffdc.sbc.com:8080/nagios/cgi-bin/status.cgi?host=";
  my $GRAPH_URL= "http://$cred\@fltva076.ffdc.sbc.com:8080/pnp4nagios/image?source=0&graph_width=800&start=-1day&host=";
  my @services = (
    { name => 'FTP', title => 'FTP Response Time', img   => ['&srv=FTP'] },
    { name => 'HTTP', title => 'HTTP Response Time', img   => ['&srv=HTTP'] },
    { name => 'MYSQL Queries per Second', title => 'MySQL Queries per Second', img   => ['&srv=MYSQL_Queries_per_Second', '&source=1&srv=MYSQL_Queries_per_Second'] },
    { name => 'MYSQL Threads Connected', title => 'MySQL Threads Connected', img   => ['&srv=MYSQL_Threads_Connected', '&source=1&srv=MYSQL_Threads_Connected'] },
    { name => 'PING', title => 'Ping Round Trip Times & Packets Lost', img   => ['&srv=PING', '&source=1&srv=PING'] },
    { name => 'SFTP', title => 'SFTP Response Time', img   => ['&srv=SFTP'] },
    { name => 'SSH', title => 'SSH Response Time', img   => ['&srv=SSH'] },
    { name => 'DOXTG', title => 'YP doxTG Jobs Executed & Failed', img   => ['&srv=DOXTG','&source=1&srv=DOXTG'] }
  );

  my $nagios_hostname = $machine->{domainname} eq 'ffdc.sbc.com' ? $machine->{hostname} : $machine->{hostname}.".".$machine->{domainname};

  my $content = LWP::Simple::get $STAT_URL.$nagios_hostname;

  my @machineServices = ();
  my $machineStatus = 'UNKNOWN';

  foreach my $service (@services) {
    my $status  = 'UNKNOWN';
    my $statusinfo = 'UNKNOWN';
    my $lastcheck = '';
    my $service_nameURL = $service->{name}; $service_nameURL =~ s/ /\\+/g;
    my $service_name = $service->{name};

    ($status, $lastcheck, $statusinfo) = ($1, $2, $3) if $content =~ /service=${service_nameURL}'>${service_name}<.*?<td class='status(.*?)'>.*?' nowrap>(\d\d-\d\d-\d\d\d\d \d\d:\d\d:\d\d)<\/td>.*?valign='center'>(.*?)<\/td>/s;
    $statusinfo =~ s/&nbsp;//g;
    my @img = map { $GRAPH_URL.$machine->{hostname}.$_ } @{$service->{img}};

    push @machineServices, { name => $service_name, title => $service->{title}, status => $status, statusinfo => $statusinfo, lastcheck => $lastcheck, img => \@img }  if $status ne 'UNKNOWN';
    
    $machineStatus = 'CRITICAL' if $status eq 'CRITICAL';
    if ($machineStatus ne 'CRITICAL') {
      $machineStatus = 'WARNING' if $status eq 'WARNING';
    }
    if ($machineStatus ne 'CRITICAL' and $machineStatus ne 'WARNING') {
      $machineStatus = 'OK' if $status eq 'OK';
    }
  }
  $machine->{host}     = $nagios_hostname;
  $machine->{status}   = $machineStatus;
  $machine->{services} = \@machineServices;

  return $machine;
}

sub machineStats ($) {
  my $id = shift;
  my $machine;

  if ($id) {
    $machine = Controller::findFirstOf('Machines', $id)
  } else {
    my $hostname = Net::Domain::hostname();
    $machine = { id => 0, 
                    hostname => $hostname, 
                    domainname => Net::Domain::hostdomain(), 
                    ip => inet_ntoa(scalar gethostbyname( $hostname || 'localhost' )), 
                    description => "doxTG Server",
                    dc_id => 1,
                };
  }

  $machine = machineNagiosStatus($machine);
  return $machine;
}

sub stats () {
  my @results = ();

  my @machines = Controller::findAllOf('Machines');
  my $hostname = Net::Domain::hostname();
  unshift @machines, { id => 0, 
                    hostname => $hostname, 
                    domainname => Net::Domain::hostdomain(), 
                    ip => inet_ntoa(scalar gethostbyname( $hostname || 'localhost' )), 
                    description => "doxTG Server",
                    dc_id => 1,
                  };
  foreach my $machine (@machines) {
    $machine = machineNagiosStatus($machine);
    push @results, { id => $machine->{id}, host => $machine->{host}, ip => $machine->{ip}, status => $machine->{status} };
  }
  return \@results;
}

sub count () {
  my $total = database->quick_count('Machines', {});
  return { total => $total }
}

sub create_update ($) {
  return 0 if ! Controller::amIAdmin;
  my $params = shift;
  return intoDB( 'Machines', $params );
}

# GET /machines
# List all the Machines
sub index () {
  my @machines = findAllOf('Machines');
  foreach my $machine (@machines) {
    $machine->{dc} = ${ database->quick_select('Datacenters', { id => $machine->{dc_id} }, { colums => ['name']} ) }{name};
  }
  return { machines => \@machines, pager => Controller::pager(scalar @machines, param( 'per' ), param( 'cur' )) }
}

# GET /machines/new
# Render a form to create a new Machine
sub new () {
  return { error => "You need to be Admin to create a new Machine." } if ! Controller::amIAdmin;
  my @datacenters = findAllOf('Datacenters');
  return { datacenters => \@datacenters };
};

# POST /machines
# Insert/Create a new Machine with the data provided from the create form.
sub create ($) {
  return { error => "You need to be Admin to create this Machine." } if ! Controller::amIAdmin;
  my $params = shift;
    if ( create_update( $params ) ) {
    flash success => "Machine '".$params->{hostname}."' sucessfuly created/updated.";
  } else {
    flash error => "Something happen, the Machine '".$params->{hostname}."' could not be created/upated.";
  }; 
}

# GET /machines/1/edit
# Render a Machine data in a form to be updated.
sub edit ($) {
  return { error => "You need to be Admin to edit this Machine." } if ! Controller::amIAdmin;
  my $params = shift;
  my $id = $params->{id};

  my $machine = findFirstOf('Machines', $id);
  my @datacenters = findAllOf('Datacenters');
  return { machine => $machine, datacenters => \@datacenters }
}

# POST /machines/1
# Update a Machine with the data provided from the edit form.
# TODO: Should be used PUT insted of POST but it cannot be in a form. Need to find a way to send a PUT request.
sub update ($) {
  return { error => "You need to be Admin to update this Machine." } if ! Controller::amIAdmin;
  my $params = shift;
    if ( create_update( $params ) ) {
    flash success => "Machine '".$params->{hostname}."' sucessfuly created/updated.";
  } else {
    flash error => "Something happen, the Machine '".$params->{hostname}."' could not be created/upated.";
  }; 
}

# GET /machines/1
# Render one Machine
sub show ($) {
  my $params = shift;

  my $machine = findFirstOf('Machines', $params->{id});
  my $datacenter = findFirstOf('Datacenters', $machine->{dc_id});

  my @containers = database->quick_select('Containers', { machine_id => $machine->{id} });
  return { machine => $machine, datacenter => $datacenter, containers => \@containers }
}

true;