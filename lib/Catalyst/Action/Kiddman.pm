package Catalyst::Action::Kiddman;

use strict;

use parent 'Catalyst::Action';

use String::Random;
use Kiddman::Client::Fetcher;
use Catalyst::ActionChain; 
use URI;

=head1 NAME

Catalyst::Action::Kiddman - Handle Kiddman pages

=head1 SYNOPSIS

 package MyApp::Controller::Kiddman;

 use warnings;
 use strict;

 use parent 'Catalyst::Controller';

 __PACKAGE__->config(
     # You must specify this configuration:
     Kiddman => {
         site_id => 1, # Kiddman site id
         url     => 'http://localhost:3000', # Kiddman Base URL
     }
 );

 sub setup : Chained('/') PathPart('content') CaptureArgs(0) {
 }

 # Kiddman ActionClass, attribute - the URL comes from $c->req->args
 sub kiddman_page : Chained('setup') Args ActionClass('Kiddman') {
     my ( $self, $c ) = @_;
     # You can modify args:
     my @args = @{ $c->req->args };
     shift @args;
     $c->req->args(\@args);

     # Now, the ActionClass automatically dispatches to Kiddman and continues,
 }

=head1 DESCRIPTION

Catalyst::Action::Kiddman is an action class wrapper for L<Kiddman>, which
abstracts the fetching and handling of the Kiddman request to a simple 
ActionClass.

=head2 HANDLING THE RESULT

The response from Kiddman is a L<Kiddman::Page> object, which is merged after
execution into C<< $c->stash->{page} >> using L<Catalyst::Utils/merge_hashes>
with precedence coming from the Kiddman object (to override defaults).

=head2 ERROR HANDLING

On failure to fetch the page from Kiddman first will try to dispatch to the
controller's C<default> action, and failing that will dispatch to "/default".

=cut

sub dispatch {
    my ( $self, $c ) = @_;

    unless ( defined $self->{_fetcher} ) {
        my %opts = ();
        if ( $c->can('cache') ) {
            $opts{cache} = $c->cache;
        }
        $self->{_fetcher} = Kiddman::Client::Fetcher->new(%opts);
    }

    my $path = $c->req->uri;
    my $base = $c->req->base;
    if ( $c->config->{using_frontend_proxy} ) {
        ( $base, $path ) = $self->_private_path($c);
    }

    my $controller = $c->component( $self->class );

    my $site_id  = $controller->{'Kiddman'}->{site_id};
    my $base_url = $controller->{'Kiddman'}->{url};
    my $key      = $controller->{'Kiddman'}->{purge_key};

    if ( not $key ) {
        $key = String::Random::random_string('....................');
    }

    unless ( $base_url and $site_id ) {
        die "ActionClass('Kiddman') requires controller configures site_id and url, please view `perldoc Catalyst::ActionClass::Kiddman`\n";
    }

    # The PathPart to send to Kiddman
    my @args = @{ $c->req->args };
    $c->execute( $self->class, $self );

    # Refetch args
    @args = @{ $c->req->args };

    my $url  = join("/", @args);
    my $page;

    if ( not defined $page ) {
        if ( $c->req->params->{kiddman_action} eq 'purge' ) {
            $self->_purge( $c->req->params->{kiddman_key} );
        }

        $page = eval { 
            $self->_fetch( $base_url, $site_id, $url, 
                { trackback => $path, key => $key } 
            ); 
        };

        if ( $@ ) {
            $c->log->error($@);
        }
        if ( $@ or not defined $page ) {
            my $default = $controller->action_for('default');
            unless ( defined $default ) {
                $default = $c->controller('Root')->action_for('default');
            }
            if ( $c->debug ) {
                $c->log->debug("Failed fetching $url from Kiddman");
                $c->log->debug("Detaching to $default");
            }
            $c->detach("/$default");
        }
    }

    if($page->can('execute')) {
        $page->execute($c);
    }

    my $source = $c->stash->{page} || {};

    # Now that we have a page, merge it
    $c->stash->{page} = Catalyst::Utils::merge_hashes($source, $page);
}

sub _fetch {
    my $self = shift;
    return $self->{_fetcher}->fetch( @_ );
}

sub _private_path {
    my ( $self, $c ) = @_;

    local (*ENV) = $c->engine->env || \%ENV;

    my $scheme    = 'http';
    my $host      = $ENV{SERVER_NAME};
    my $port      = $ENV{SERVER_PORT} || ( $c->request->secure ? 443 : 80 );
    my $base_path;
    if ( exists $ENV{REDIRECT_URL} ) {
        $base_path = $ENV{REDIRECT_URL};
        $base_path =~ s/$ENV{PATH_INFO}$//;
    }
    else {
        $base_path = $ENV{SCRIPT_NAME} || '/';
    }

    # set the request URI
    my $path = $base_path . ( $ENV{PATH_INFO} || '' );
    $path =~ s{^/+}{};

    # Using URI directly is way too slow, so we construct the URLs manually
    my $uri_class = "URI::$scheme";

    # HTTP_HOST will include the port even if it's 80/443
    $host =~ s/:(?:80|443)$//;

    if ( $port !~ /^(?:80|443)$/ && $host !~ /:/ ) {
        $host .= ":$port";
    }

    # Escape the path
    $path =~ s/([^$URI::uric])/$URI::Escape::escapes{$1}/go;
    $path =~ s/\?/%3F/g; # STUPID STUPID SPECIAL CASE

    my $query = $ENV{QUERY_STRING} ? '?' . $ENV{QUERY_STRING} : '';
    my $uri   = $scheme . '://' . $host . '/' . $path . $query;

    my $uri = bless \$uri, $uri_class;
    # set the base URI
    # base must end in a slash
    $base_path .= '/' unless $base_path =~ m{/$};

    my $base_uri = $scheme . '://' . $host . $base_path;
    $base_uri = bless \$base_uri, $uri_class;

    return ( $base_uri, $uri );
}

1;
