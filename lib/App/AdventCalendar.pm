package App::AdventCalendar;
use strict;
use warnings;
our $VERSION = '0.01';

use Plack::Request;
use Router::Simple;
use Text::Xslate qw/mark_raw/;
use Path::Class;
use Time::Piece;
use Time::Seconds;
use Text::Xatena;
use Encode;

my $router = Router::Simple->new();
$router->connect(
    '/pull',
    { controller => 'Calendar', action => 'pull' }
);
$router->connect(
    '/{year:\d{4}}/',
    { controller => 'Calendar', action => 'track_list' }
);
$router->connect(
    '/{year:\d{4}}/{name:[a-zA-Z0-9_-]+?}/',
    { controller => 'Calendar', action => 'index' }
);
$router->connect(
    '/{year:\d{4}}/{name:[a-zA-Z0-9_-]+?}/{day:\d{1,2}}',
    { controller => 'Calendar', action => 'entry' }
);

sub handler {
    my $env = shift;

    if ( my $p = $router->match($env) ) {
        my $root = dir( 'assets', $p->{year}, $p->{name} );
        return not_found() unless -d $root;

        my $req  = Plack::Request->new($env);
        my $vars = { req => $req, %$p };
        $vars->{tracks} = [map { $_->dir_list(-1) } dir( 'assets', $p->{year} )->children(no_hidden => 1)];

        if ( $p->{action} eq 'index' ) {
            my $t = Time::Piece->strptime( "$p->{year}/12/01", '%Y/%m/%d' );
            my @entries;
            while ( $t->mday <= 25 ) {
                push @entries, {
                    date   => Time::Piece->new($t),
                    exists => -e $root->file( $t->ymd . '.txt' ) ? 1 : 0,
                };
                $t += ONE_DAY;
            }
            $vars->{entries} = \@entries;
        }
        elsif ( $p->{action} eq 'entry' ) {
            my $t = Time::Piece->strptime(
                    "$p->{year}/12/@{[sprintf('%02d',$p->{day})]}", '%Y/%m/%d' );
                my $file = $root->file($t->ymd . '.txt');

            if ( -e $file ) {
                my $text = $file->slurp();
                my ($title, $body) = split("\n\n", $text, 2);
                $vars->{title} = $title;
                my $xatena = Text::Xatena->new;
                $vars->{text} = mark_raw($xatena->format($body));
            }
            else {
                return not_found();
            }
        }
        elsif ( $p->{action} eq 'track_list' ) {
        }
        elsif ( $p->{action} eq 'pull' ) {
            system("git pull origin master");
            return [200, [], ['OK']];
        }

        my $tx = Text::Xslate->new(
            syntax    => 'TTerse',
            path      => [$root->subdir('tmpl'), dir('assets','tmpl')],
            cache_dir => '/tmp/app-adventcalendar',
            cache     => 1,
            function  => {
                uri_for => sub {
                    my($path, $args) = @_;
                    my $uri = $req->base;
                    $uri->path($uri->path . $path);
                    $uri->query_form(@$args) if $args;
                    $uri;
                },
            },
        );
        return [
            200,
            [ 'Content-Type' => 'text/html' ],
            [ encode('utf-8', $tx->render( "$p->{action}.html", $vars )) ]
        ];
    }
    else {
        return not_found();
    }
}

sub not_found {
    return [ 404, [ 'Content-Type' => 'text/html' ], ['Not Found'] ];
}

1;
__END__

=head1 NAME

App::AdventCalendar -

=head1 SYNOPSIS

  use App::AdventCalendar;

=head1 DESCRIPTION

App::AdventCalendar is

=head1 AUTHOR

Kan Fushihara E<lt>kan@mfac.jpE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
