package Controllers;

use strict;
use warnings;

use Dancer ':syntax';

use Controllers::Contacts;
prefix "/contacts" => sub {
  get  '/search'   => sub { my $p = request->params('route'); template "search"          => Controllers::Contacts::search( $p ); };
  get  '/'         => sub { template "contacts/index" => Controllers::Contacts::index(); };
  get  '/new'      => sub { template "contacts/new"   => Controllers::Contacts::new();  };
  post '/'         => sub { my $p = request->params('body');  Controllers::Contacts::create( $p ); redirect "/contacts" };
  get  '/:id/edit' => sub { my $p = request->params('route'); template "contacts/edit"   => Controllers::Contacts::edit( $p ); };
  post '/:id'      => sub { my $p = request->params('body');  Controllers::Contacts::update( $p ); redirect "/contacts" };
  get  '/:id'      => sub { my $p = request->params('route'); template "contacts/show"   => Controllers::Contacts::show( $p ); };
};

use Controllers::Containers;
prefix "/containers" => sub {
  get  '/search'   => sub { my $p = request->params('route'); template "search"            => Controllers::Containers::search( $p ); };
  get  '/'         => sub { template "containers/index" => Controllers::Containers::index(); };
  get  '/new'      => sub { template "containers/new"   => Controllers::Containers::new();  };
  post '/'         => sub { my $p = request->params('body');  Controllers::Containers::create( $p ); redirect "/containers" };
  get  '/:id/edit' => sub { my $p = request->params('route'); template "containers/edit"   => Controllers::Containers::edit( $p ); };
  post '/:id'      => sub { my $p = request->params('body');  Controllers::Containers::update( $p ); redirect "/containers" };
  get  '/:id'      => sub { my $p = request->params('route'); template "containers/show"   => Controllers::Containers::show( $p ); };
};

use Controllers::Credentials;
prefix "/credentials" => sub {
  get  '/search'   => sub { my $p = request->params('route'); template "search"             => Controllers::Credentials::search( $p ); };
  get  '/'         => sub { template "credentials/index" => Controllers::Credentials::index(); };
  get  '/new'      => sub { template "credentials/new"   => Controllers::Credentials::new();  };
  post '/'         => sub { my $p = request->params('body');  Controllers::Credentials::create( $p ); redirect "/credentials" };
  get  '/:id/edit' => sub { my $p = request->params('route'); template "credentials/edit"   => Controllers::Credentials::edit( $p ); };
  post '/:id'      => sub { my $p = request->params('body');  Controllers::Credentials::update( $p ); redirect "/credentials" };
  get  '/:id'      => sub { my $p = request->params('route'); template "credentials/show"   => Controllers::Credentials::show( $p ); };
};

use Controllers::Files;
prefix "/files" => sub {
  get  '/search'   => sub { my $p = request->params('route'); template "search"       => Controllers::Files::search( $p ); };
  get  '/'         => sub { template "files/index" => Controllers::Files::index(); };
  get  '/new'      => sub { template "files/new"   => Controllers::Files::new();  };
  post '/'         => sub { my $p = request->params('body');  Controllers::Files::create( $p ); redirect "/files" };
  get  '/:id/edit' => sub { my $p = request->params('route'); template "files/edit"   => Controllers::Files::edit( $p ); };
  post '/:id'      => sub { my $p = request->params('body');  Controllers::Files::update( $p ); redirect "/files" };
  get  '/:id'      => sub { my $p = request->params('route'); template "files/show"   => Controllers::Files::show( $p ); };
};

use Controllers::Filetransfers;
prefix "/filetransfers" => sub {
  get  '/search'   => sub { my $p = request->params('route'); template "search"               => Controllers::Filetransfers::search( $p ); };
  get  '/'         => sub { template "filetransfers/index" => Controllers::Filetransfers::index(); };
  get  '/new'      => sub { template "filetransfers/new"   => Controllers::Filetransfers::new();  };
  post '/'         => sub { my $p = request->params('body');  Controllers::Filetransfers::create( $p ); redirect "/filetransfers" };
  get  '/:id/edit' => sub { my $p = request->params('route'); template "filetransfers/edit"   => Controllers::Filetransfers::edit( $p ); };
  post '/:id'      => sub { my $p = request->params('body');  Controllers::Filetransfers::update( $p ); redirect "/filetransfers" };
  get  '/:id'      => sub { my $p = request->params('route'); template "filetransfers/show"   => Controllers::Filetransfers::show( $p ); };
};

use Controllers::Commands;
prefix "/commands" => sub {
  get  '/search'   => sub { my $p = request->params('route'); template "search"          => Controllers::Commands::search( $p ); };
  get  '/'         => sub { template "commands/index" => Controllers::Commands::index(); };
  get  '/new'      => sub { template "commands/new"   => Controllers::Commands::new();  };
  post '/'         => sub { my $p = request->params('body');  Controllers::Commands::create( $p ); redirect "/commands" };
  get  '/:id/edit' => sub { my $p = request->params('route'); template "commands/edit"   => Controllers::Commands::edit( $p ); };
  post '/:id'      => sub { my $p = request->params('body');  Controllers::Commands::update( $p ); redirect "/commands" };
  get  '/:id'      => sub { my $p = request->params('route'); template "commands/show"   => Controllers::Commands::show( $p ); };
};

use Controllers::Quick;
use Controllers::Jobs;
prefix "/jobs" => sub {
  # These are non CRUD rules for jobs.
  get '/:id/run' => sub {
    my $p = request->params('route');
    my $results = Controllers::Jobs::execute( $p, 1, 0 );
    # redirect "jobs/".$p->{id}."/status"
    if (defined $results->{jobinstance}){
      redirect "jobinstance/".$results->{jobinstance}->{id}."/status";
    } else {
      redirect "jobs/".params->{id};
    }
  };

  get '/:id/status' => sub {
    my $p = request->params('route');
    template 'jobs/status_job', Controllers::Jobs::instances( $p );
  };

  get '/export/:format' => sub {
    content_type 'application/x-download';
    if (param('format') eq 'csv') {
      header('Content-Disposition' => "attachment;filename=doxTG_Jobs.csv");
      return Controllers::Jobs::to_csv();
    } elsif (param('format') eq 'xls') {
      header('Content-Disposition' => "attachment;filename=doxTG_Jobs.xls");
      return Controllers::Jobs::to_xls();
    }
};

  get '/import/:format' => sub {
    redirect "/jobs";
  };

  get  '/new'      => sub { template 'quick/new' => Controllers::Quick::new() };
  post '/' => sub {
    my $p = request->params('body');
    my $results = Controllers::Quick::create( $p );
    if ($results->{msgType} eq 'success') {
      redirect "/jobs/".$results->{id};
    } else {
      redirect "/jobs/new";
    }
  };


  get  '/search'   => sub { my $p = request->params('route'); template "search"      => Controllers::Jobs::search( $p ); };
  get  '/'         => sub { template "jobs/index" => Controllers::Jobs::index(); };
  # get  '/new'      => sub { template "jobs/new"   => Controllers::Jobs::new();  };
  # post '/'         => sub { my $p = request->params('body');  Controllers::Jobs::create( $p ); redirect "/jobs" };
  get  '/:id/edit' => sub { my $p = request->params('route'); template "jobs/edit"   => Controllers::Jobs::edit( $p ); };
  post '/:id'      => sub { my $p = request->params('body');  Controllers::Jobs::update( $p ); redirect "/jobs" };
  get  '/:id'      => sub { my $p = request->params('route'); template "jobs/show"   => Controllers::Jobs::show( $p ); };
};

use Controllers::Machines;
prefix "/machines" => sub {
  get  '/search'   => sub { my $p = request->params('route'); template "search"          => Controllers::Machines::search( $p ); };
  get  '/'         => sub { template "machines/index" => Controllers::Machines::index(); };
  get  '/new'      => sub { template "machines/new"   => Controllers::Machines::new();  };
  post '/'         => sub { my $p = request->params('body');  Controllers::Machines::create( $p ); redirect "/machines" };
  get  '/:id/edit' => sub { my $p = request->params('route'); template "machines/edit"   => Controllers::Machines::edit( $p ); };
  post '/:id'      => sub { my $p = request->params('body');  Controllers::Machines::update( $p ); redirect "/machines" };
  get  '/:id'      => sub { my $p = request->params('route'); template "machines/show"   => Controllers::Machines::show( $p ); };
};

use Controllers::Teams;
prefix "/teams" => sub {
  get  '/search'   => sub { my $p = request->params('route'); template "search"       => Controllers::Teams::search( $p ); };
  get  '/'         => sub { template "teams/index" => Controllers::Teams::index(); };
  get  '/new'      => sub { template "teams/new"   => Controllers::Teams::new();  };
  post '/'         => sub { my $p = request->params('body');  Controllers::Teams::create( $p ); redirect "/teams" };
  get  '/:id/edit' => sub { my $p = request->params('route'); template "teams/edit"   => Controllers::Teams::edit( $p ); };
  post '/:id'      => sub { my $p = request->params('body');  Controllers::Teams::update( $p ); redirect "/teams" };
  get  '/:id'      => sub { my $p = request->params('route'); template "teams/show"   => Controllers::Teams::show( $p ); };
};

use Controllers::JobGroups;
prefix "/jobgroups" => sub {
  get  '/search'   => sub { my $p = request->params('route'); template "search"       => Controllers::JobGroups::search( $p ); };
  get  '/'         => sub { template "jobgroups/index" => Controllers::JobGroups::index(); };
  get  '/new'      => sub { template "jobgroups/new"   => Controllers::JobGroups::new();  };
  post '/'         => sub { my $p = request->params('body');  Controllers::JobGroups::create( $p ); redirect "/jobgroups" };
  get  '/:id/edit' => sub { my $p = request->params('route'); template "jobgroups/edit"   => Controllers::JobGroups::edit( $p ); };
  post '/:id'      => sub { my $p = request->params('body');  Controllers::JobGroups::update( $p ); redirect "/jobgroups" };
  get  '/:id'      => sub { my $p = request->params('route'); template "jobgroups/show"   => Controllers::JobGroups::show( $p ); };
};

use Controllers::Filewatchers;
prefix "/filewatchers" => sub {
  get  '/search'   => sub { my $p = request->params('route'); template "search"              => Controllers::Filewatchers::search( $p ); };
  get  '/'         => sub { template "filewatchers/index" => Controllers::Filewatchers::index(); };
  get  '/new'      => sub { template "filewatchers/new"   => Controllers::Filewatchers::new();  };
  post '/'         => sub { my $p = request->params('body');  Controllers::Filewatchers::create( $p ); redirect "/filewatchers" };
  get  '/:id/edit' => sub { my $p = request->params('route'); template "filewatchers/edit"   => Controllers::Filewatchers::edit( $p ); };
  post '/:id'      => sub { my $p = request->params('body');  Controllers::Filewatchers::update( $p ); redirect "/filewatchers" };
  get  '/:id'      => sub { my $p = request->params('route'); template "filewatchers/show"   => Controllers::Filewatchers::show( $p ); };
};

use Controllers::Schedules;
prefix "/schedules" => sub {
  get  '/search'   => sub { my $p = request->params('route'); template "search"           => Controllers::Schedules::search( $p ); };
  get  '/'         => sub { template "schedules/index" => Controllers::Schedules::index(); };
  get  '/new'      => sub { template "schedules/new"   => Controllers::Schedules::new();  };
  post '/'         => sub { my $p = request->params('body');  Controllers::Schedules::create( $p ); redirect "/schedules" };
  get  '/:id/edit' => sub { my $p = request->params('route'); template "schedules/edit"   => Controllers::Schedules::edit( $p ); };
  post '/:id'      => sub { my $p = request->params('body');  Controllers::Schedules::update( $p ); redirect "/schedules" };
  get  '/:id'      => sub { my $p = request->params('route'); template "schedules/show"   => Controllers::Schedules::show( $p ); };
};

use Controllers::Conditions;
prefix "/conditions" => sub {
  get  '/search'   => sub { my $p = request->params('route'); template "search"            => Controllers::Conditions::search( $p ); };
  get  '/'         => sub { template "conditions/index" => Controllers::Conditions::index(); };
  get  '/new'      => sub { template "conditions/new"   => Controllers::Conditions::new();  };
  post '/'         => sub { my $p = request->params('body');  Controllers::Conditions::create( $p ); redirect "/conditions" };
  get  '/:id/edit' => sub { my $p = request->params('route'); template "conditions/edit"   => Controllers::Conditions::edit( $p ); };
  post '/:id'      => sub { my $p = request->params('body');  Controllers::Conditions::update( $p ); redirect "/conditions" };
  get  '/:id'      => sub { my $p = request->params('route'); template "conditions/show"   => Controllers::Conditions::show( $p ); };
};

use Controllers::Admin::Users;
prefix "/users" => sub {
  get  '/search'   => sub { my $p = request->params('route'); template "search"             => Controllers::Admin::Users::search( $p ); };
  get  '/'         => sub { template "admin/users/index" => Controllers::Admin::Users::index(); };
  get  '/new'      => sub { template "admin/users/new"   => Controllers::Admin::Users::new();  };
  post '/'         => sub { my $p = request->params('body');  Controllers::Admin::Users::create( $p ); redirect "/users" };
  get  '/:id/edit' => sub { my $p = request->params('route'); template "admin/users/edit"   => Controllers::Admin::Users::edit( $p ); };
  post '/:id'      => sub { my $p = request->params('body');  Controllers::Admin::Users::update( $p ); redirect "/users" };
  get  '/:id'      => sub { my $p = request->params('route'); template "admin/users/show"   => Controllers::Admin::Users::show( $p ); };
};

use Controllers::Admin::Roles;
prefix "/roles" => sub {
  get  '/search'   => sub { my $p = request->params('route'); template "search"             => Controllers::Admin::Roles::search( $p ); };
  get  '/'         => sub { template "admin/roles/index" => Controllers::Admin::Roles::index(); };
  get  '/new'      => sub { template "admin/roles/new"   => Controllers::Admin::Roles::new();  };
  post '/'         => sub { my $p = request->params('body');  Controllers::Admin::Roles::create( $p ); redirect "/roles" };
  get  '/:id/edit' => sub { my $p = request->params('route'); template "admin/roles/edit"   => Controllers::Admin::Roles::edit( $p ); };
  post '/:id'      => sub { my $p = request->params('body');  Controllers::Admin::Roles::update( $p ); redirect "/roles" };
  get  '/:id'      => sub { my $p = request->params('route'); template "admin/roles/show"   => Controllers::Admin::Roles::show( $p ); };
};

true;
