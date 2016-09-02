#!/usr/bin/perl
#
# Traverses a website recursively, making sure that all links do not
# return 404.

use strict;
use warnings;
use WWW::Mechanize;

my $debug = 0;
my $abortMax = 1000;

if( @ARGV < 2 ) {
    print STDERR "Synopsis: $0 <start-url> <filter-url>...\n";
    print STDERR "    where start-url:  the first URL to be accessed,\n";
    print STDERR "          filter-url: one or more URLs with which found links must start to continue recursive traversal\n";
    print STDERR "    e.g. $0 http://localhost/index.html http://localhost https://localhost\n";
    print STDERR "          will only follow URLs on the local host\n";
    exit 1;
}

my %toDo = ();
$toDo{shift @ARGV} = 1;
my @regexes;
if( @ARGV ) {
    @regexes = map { '^' . quotemeta( $_ ) } @ARGV;
} else {
    @regexes = ( '^.' );
}
my %done  = ();
my %fails = ();

my $mech = WWW::Mechanize->new( onerror => undef );

OUTER: while( keys %toDo ) {
    if( $debug ) {
        print "To do: " . join( ' ', keys %toDo ) . "\n";
    }
    my %newToDo = ();
    foreach my $toDo ( keys %toDo ) {
        my $response = $mech->get( $toDo );
        $done{$toDo} = 1;
        if( $response->is_success ) {
            my @links = $mech->links();
            @links = map { $_->url_abs() } @links;
            @links = map { my $s = $_; $s =~ s!#.*!!g; $s; } @links;
            @links = grep {
                     my $u = $_;
                     my $ret = 0;
                     foreach my $r ( @regexes ) {
                         if( $u =~ $r ) {
                             $ret = 1;
                             last;
                         }
                    }
                    $ret;
            } @links;
            if( $debug > 1 ) {
                print "$toDo -> " . join( ', ', @links ) . "\n";
            }
            @links = grep { !$done{$_} } @links;
            map { $newToDo{$_} = 1 } @links;
        } else {
            print STDERR "Failed: $toDo -> " . $response->status_line . "\n";
            $fails{$toDo} = $response->status_line;
        }
        --$abortMax;
        if( $abortMax <= 0 ) {
            print STDERR "Too many links. Aborting.\n";
            last OUTER;
        }
    }
    %toDo = %newToDo;
}

if( %fails ) {
    exit 1;
} else {
    exit 0;
}

1;

