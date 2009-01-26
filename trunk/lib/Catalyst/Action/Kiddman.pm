package Catalyst::Action::Kiddman;

use strict;

use parent 'Catalyst::Action';

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

    my $controller = $c->component( $self->class );

    my $site_id  = $controller->{'Kiddman'}->{site_id};
    my $base_url = $controller->{'Kiddman'}->{url};

    unless ( $base_url and $site_id ) {
        die "ActionClass('Kiddman') requires controller configures site_id and url, please view `perldoc Catalyst::ActionClass::Kiddman`\n";
    }

    # The PathPart to send to Kiddman
    my @args = @{ $c->req->args };
    $c->execute( $self->class, $self );

    # Refetch args
    @args = @{ $c->req->args };

    my $url  = join("/", @args);
    $c->log->debug("Looking for '$url' from Kiddman");
    my $page = eval { $self->_fetch( $base_url, $site_id, $url ); };

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

    if($page->can('execute')) {
        $page->execute($c);
    }

    my $source = $c->stash->{page} || {};

    # Now that we have a page, merge it
    $c->stash->{page} = Catalyst::Utils::merge_hashes($source, $page);
}

sub _fetch {
    my ( $self, $base, $site_id, $url ) = @_;
    return Kiddman::Client::Fetcher::fetch( $base, $site_id, $url );
}


1;
