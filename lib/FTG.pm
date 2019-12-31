package FTG;

use strict;
use warnings;

use Dancer ':syntax';
use Dancer::Plugin::Database;
use Dancer::Plugin::FlashMessage;
# use Dancer::Plugin::NYTProf;
use Data::SpreadPagination;
use File::Basename qw/fileparse/;
use Net::Domain;
use Socket;

our $VERSION = '0.1';

# Comment out this line if you don't want authentication in the system.
use Authentication;

use Controller qw(getAccessHistory getDBToday);
use JIL;
use Searches;

# Rule commun to all the resources.
# POST /<resource>/1/delete
# Deletes an resource
# TODO: Should be used DELETE /resources/1 but it is not possible to send a DELETE request in a form. Need to find a way to send a DELETE request.
post '/:resource/:id/delete' => sub {
  my $resource = params->{resource};
  database->quick_delete(ucfirst( $resource ), { id => params->{id} });
  $resource =~ /(.*)s/;
  flash success => ucfirst( $1 )." (#".params->{id}.") sucessfuly deleted.";
  redirect "/$resource";
};

sub makeRule ($) {
  my $resource = shift;
  eval "use Controllers::".ucfirst($resource);

  prefix "/$resource" => sub {
    get  '/'         => sub { template "$resource/index" => eval("Controllers::".ucfirst($resource)."::index()"); };
    get  '/new'      => sub { template "$resource/new"   => eval("Controllers::".ucfirst($resource)."::new()");  };
    post '/'         => sub { my $p = request->params('body');  eval ('Controllers::'.ucfirst($resource).'::create( $p )'); redirect "/$resource" };
    get  '/:id/edit' => sub { my $p = request->params('route'); template "$resource/edit"   => eval ('Controllers::'.ucfirst($resource).'::edit( $p )'); };
    post '/:id'      => sub { my $p = request->params('body');  eval ('Controllers::'.ucfirst($resource).'::update( $p )'); redirect "/$resource" };
    get  '/:id'      => sub { my $p = request->params('route'); template "$resource/show"   => eval ('Controllers::'.ucfirst($resource).'::show( $p )'); };
  };
}

# ROOT Rule

get '/' => sub {
  my $jobStats      = Controllers::Jobs::stats();
  my $machineStats  = Controllers::Machines::count();
  my $contactStats  = Controllers::Contacts::stats();
  my $accessHistory = Controller::getAccessHistory();
  my $pager         = Controller::pager(scalar @{$jobStats->{jobinstances}}, param( 'per' ), param( 'cur' ));

  template 'dashboard' => { jobStats => $jobStats, machineStats => $machineStats, contactStats => $contactStats, accessHistory => $accessHistory, pager => $pager, }
};

# JOBINSTANCES Rules

get '/jobinstance/:id/status' => sub {
  if ( param( 'simple' ) ) {
    return template 'jobs/status_instance_simple', Controllers::Jobs::instance( params->{id} ), { layout => '' };
  } 
  template 'jobs/status_instance' => Controllers::Jobs::instance( params->{id} ); # , { layout => 'main_refresh.tt' };
};

get '/jobinstance/search' => sub {
  my $p = request->params('route'); 
  template "search" => Controllers::Jobs::searchJobInstance( $p )
};

# JIL IMPORT / EXPORT Rules

get '/import/:file' => sub {
  my $file   = params->{file};
  return template 'admin/import/import' if (! $file);

  my ($name,$path,$suffix) = fileparse($file,".jil",".sql");

  if ( $suffix ne ".jil" && $suffix ne ".sql" ) {
    flash 'error' => "File loaded is not a JIL or SQL file";
    return template 'admin/import/import';
  }

  my $appdir = config->{appdir};
  my $fullpath = $appdir . "/tmp/" . $name . $suffix ;
  if (! -e $fullpath) {
    flash 'error' => "File $file does not exists";
    return template 'admin/import/import';
  }    

  if ( $suffix eq ".jil" ) {
    my $result = JIL::loadFile($fullpath);
    flash $result->{msgType} => $result->{message};
    return template 'admin/import/import';
  }

  flash 'error' => 'I do not know what but something happen :(';
  template 'admin/import/import';
};

post '/import' => sub {
  my $file   = params->{file};

  return template 'admin/import/import' if (! $file);
  $file = 'test.jil';
  my ($name,$path,$suffix) = fileparse($file,".jil",".sql");
  
  if ( $suffix ne ".jil" && $suffix ne ".sql" ) {
    flash 'error' => "File loaded is not a JIL or SQL file";
    return template 'admin/import/import';
  }

  my $appdir = config->{appdir};
  my $fullpath = $appdir . "/tmp/" . $name . $suffix ;
  if (! -e $fullpath) {
    flash 'error' => "File $file does not exists";
    return template 'admin/import/import';
  }  

  if (! open FILE,"<",$fullpath ) {
    flash 'error' => "Failed to open the file $file: $!";
    return template 'admin/import/import';
  }
  my @lines = <FILE>;
  close FILE;
  template 'admin/import/import' => { file => $name.$suffix, source => join("",@lines) };
};

# SEARCH Rule

get '/search' => sub {
  my $query = params->{query};

  my $results = Searches::basicSearch($query);

  if (defined $query and defined $results) {
    if ($results->{total} > 0) {
      flash 'info' => "<b>$results->{total}</b> results found.";
    } else {
      flash 'warning' => "No results found.";
    }
  }

  template 'search' => { query => $query, results => $results };
};

get '/monitor' => sub {
  template 'machines/monitoring_index' => { machines => Controllers::Machines::stats() }
};

get '/machines/:id/status' => sub {
  template 'machines/status_machine' => { machine => Controllers::Machines::machineStats(param('id')) };
};

# TODO: You may load the module 'Controllers' or 'makeRule' for each module. For development is better to load the module to catch errors.
# TODO: Exclude Jobs from the Controllers or include Quick into Jobs
# makeRule($_) for (qw/contacts containers credentials files filetransfers jobs machines teams filewatchers schedules conditions/);
load_app 'Controllers';

# Get IP Rule

get "/ip/:host" => sub {
  my @address = gethostbyname( params->{host} );
  my @ips = map { inet_ntoa($_) } @address[4 .. $#address];
  content_type 'application/json';

  return to_json { host => params->{host}, ip => $ips[0] };
};

# Other Rules

for my $p (qw/dashboard calendar faq help/) {
  get "/$p" => eval qq|sub { template '$p' }|;
}

# # Accounts
# for my $p (qw/reset-password sign-in sign-up user users/) {
#   get "/$p" => eval qq|sub { template 'accounts/$p' }|;
# }

# Legal
for my $p (qw/privacy-policy terms-and-conditions/) {
  get "/$p" => eval qq|sub { template 'legal/$p' }|;
}

# # Examples

# use Cwd;
# use Sys::Hostname;

# use examples::simple_form;
# use examples::navbar_login;
# use examples::tabs;
# use examples::show_file;
# use examples::photo_gallery;
# use examples::markdown;
# use examples::template_plugins;
# use examples::error_handling;
# use examples::dynamic_content;

# for my $p (qw/media/) {
#   get "/$p" => eval qq|sub { template 'examples/$p' }|;
# }

# get '/deploy' => sub {
#     template 'examples/deployment_wizard', {
#     directory => getcwd(),
#     hostname  => hostname(),
#     proxy_port=> 8000,
#     cgi_type  => "fast",
#     fast_static_files => 1,
#   };
# };

# #The user clicked "updated", generate new Apache/lighttpd/nginx stubs
# post '/deploy' => sub {
#     my $project_dir = param('input_project_directory') || "";
#     my $hostname = param('input_hostname') || "" ;
#     my $proxy_port = param('input_proxy_port') || "";
#     my $cgi_type = param('input_cgi_type') || "fast";
#     my $fast_static_files = param('input_fast_static_files') || 0;

#     template 'examples/deployment_wizard', {
#     directory => $project_dir,
#     hostname  => $hostname,
#     proxy_port=> $proxy_port,
#     cgi_type  => $cgi_type,
#     fast_static_files => $fast_static_files,
#   };
# };

true;
