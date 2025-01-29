use strict;
use warnings;

use Lenio;
use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use Log::Report mode => 'NORMAL';

my $app = Lenio->to_app;
is( ref $app, 'CODE', 'Got app' );

my $test = Plack::Test->create($app);
my $res  = $test->request( GET '/' );

ok( $res->is_redirect, '[GET /] successful' );

is(
    $res->headers->header('Location'),
    'http://localhost/login?return_url=%2F',
    '/loggedin redirected to login page when not logged in'
);

$res = $test->request( POST '/login', [ username => 'foo', password => 'bar' ] );

ok($res->is_redirect, "Response is redirect");
is($res->header('location'), '/login', 'Login with fake details redirects back to login');

done_testing;
