BEGIN {
  use Test::Most;
  eval "use Catalyst 5.90090; 1" || do {
    plan skip_all => "Need a newer version of Catalyst => $@";
  };
}
{
  package MyApp::Controller::Root;
  use base 'Catalyst::Controller';

  sub test :Local {
    my ($self, $c) = @_;
    $c->res->body('test');
    Test::Most::is($c->req->choose_media_type('text/html','application/json'), undef);

  }

  sub choose_media_type :Local {
    my ($self, $c) = @_;
    $c->res->body('json');

    Test::Most::is($c->req->choose_media_type('text/html','application/json'), 'application/json');
  }

  $INC{'MyApp/Controller/Root.pm'} = __FILE__;

  package MyApp;
  use Catalyst;
  
  MyApp->request_class_traits(['Catalyst::TraitFor::Request::ContentNegotiationHelpers']);
  MyApp->setup;
}

use HTTP::Request::Common;
use Catalyst::Test 'MyApp';

{
  ok my $res = request GET '/root/choose_media_type', Accept => 'application/json';
  is $res->content, 'json';
}

ok my ($res, $c) = ctx_request('/root/test');

done_testing;
