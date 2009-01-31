package Kiddman::Client::Fetcher;

use Moose;

use Carp;
use Class::MOP;
use LWP::UserAgent;
use JSON::XS;

has 'cache' => (
    is  => 'rw',
    isa => 'Cache',
);

has 'timeout' => (
    is  => 'rw',
    isa => 'Int',
    default => 10
);

has 'ua' => (
    is      => 'rw',
    isa     => 'LWP::UserAgent',
    lazy    => 1,
    builder => '_build_ua',
);

sub _build_ua {
    my ( $self ) = @_;

    my $ua = LWP::UserAgent->new;
    $ua->timeout( $self->timeout );

    $self->ua( $ua );
}

sub purge {
    my ($self, $url, $siteid, $path, $key) = @_;
    croak "Can't purge, no cache specified" unless $self->cache;

    $path = "/$path" unless $path =~ m#^/#;

    my $fetch_uri = URI->new("$url/site/$siteid/fetch_url");
    $fetch_uri->query_form({ path => $path });

    my $content;

    my $cache_entity = $self->cache->get($fetch_uri);
    if ( not $cache_entity->{key} or
         $cache_entity->{key} eq $key
    ) {
        $self->cache->remove( $fetch_uri );
    }
}

sub fetch {
    my ($self, $url, $siteid, $path, $args) = @_;
    $path = "/$path" unless $path =~ m#^/#;

    my $fetch_uri = URI->new("$url/site/$siteid/fetch_url");
    $fetch_uri->query_form({ path => $path });

    my $content;
    my $cache_key = "$fetch_uri";
    if ( defined $self->cache ) {
        my $cache_entity = $self->cache->get($cache_key);
        $content = $cache_entity->{content};
    } 

    unless ( $content ) {
        $args->{path} = $path;
        $fetch_uri->query_form( $args );

        my $ua   = $self->ua;
        my $resp = $ua->get("$fetch_uri");

        if ( $resp->is_success ) {
            $content = $resp->content;
            my $ttl  = 86400 * 365; # TODO: Check expires header?
            if ( $self->cache ) {

                $self->cache->set( $cache_key, $content, $ttl );
            }
        } else {
            if ( $resp->code == 404 ) {
                return undef;
            } else {
                croak($resp->status_line);
            }
        }
    }
    return undef unless $content;

    my $inst = JSON::XS::decode_json($content);

    if ( defined $inst->{page} ) {
        Class::MOP::load_class($inst->{page});
        return $inst->{page}->new($inst->{options});
    }
    return $inst;
}

1;
