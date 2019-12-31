package Authentication;

use strict;
use warnings;

use Dancer ':syntax';
use Dancer::Plugin::Database;

use Controller qw(accessLogEntry);
use Controllers::Admin::Roles;

use Crypt::SaltedHash;

#use Controller;

=pod

=cut

hook 'before' => sub {
  if (! session('user') && request->path_info !~ m{^/login}) {
    var requested_path => request->path_info;
    request->path_info('/login');
  } else {
    accessLogEntry(request,"");
  }
};

hook 'before_template_render' => sub {
    my $tokens = shift;
    #$tokens->{username} = 'USER';
    if (session->{user}) {
      $tokens->{username} = session->{user} ;
      my $role_id         = database->quick_lookup('Users', { username => session->{user} }, 'role_id');
      $tokens->{role}     = Controllers::Admin::Roles::get_role_name($role_id); # database->quick_lookup('Roles', { id => $role_id }, 'name');
    }  
};

get '/login' => sub {
  # Display a login page; the original URL they requested is available as
  # vars->{requested_path}, so could be put in a hidden field in the form
  my $warning = '';
  $warning = 'Wrong username or password' if params->{failed} and params->{failed} == 1;
  $warning = 'Missing username' if params->{failed} and params->{failed} == 2;
  template 'accounts/sign-in', { path => vars->{requested_path}, show_warning => $warning };
};

post '/login' => sub {
  my $username = params->{username};
  my $password = params->{password};

  # Just for testing, allow access to everybody
  # session user => $username;
  # redirect params->{path} || '/';
  # return;

  $username =~ s/^\s*//;
  $username =~ s/\s*$//;
  if (length($username)==0) {
    warning "Missing username";
    redirect '/login?failed=2' ;
  } else {
    my $user = database->quick_select('Users', {username => $username});
    if ( ! $user ) {
      warning "Login failed: User '$username' not found";
      redirect '/login?failed=1';
    } else {
      my $valid = Crypt::SaltedHash->validate($user->{password}, $password);
      # if (! $user or $password ne $user->{password}) {
      if ( Crypt::SaltedHash->validate($user->{password}, $password) ) {
        session user => $username;
        my $contact = database->quick_select('Contacts', { id => $user->{contact_id} });
        my $userData = 'NOBODY';
        $userData = $contact->{firstname}." ".$contact->{lastname}." (".$contact->{email}.")" if $contact;
        session userdata => $userData;

        accessLogEntry(request, "login sucessful for user '$username' assigned to $userData");

        redirect params->{path} || '/';
        } else {
          warning "Login failed: Password incorrect for '$username'";
          redirect '/login?failed=1';
        }
    }
  }
};

get '/logout' => sub {
  my $username = session->{user} if (session->{user});
  accessLogEntry(request, "logout sucessful for user '$username'");  
  session->destroy;
  template '/accounts/sign-in';
};


true;