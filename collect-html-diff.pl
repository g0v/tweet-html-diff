#!/usr/bin/env perl
use v5.14;
use strict;
use warnings;
use Digest::SHA1 'sha1_hex';
use Encode qw< decode encode_utf8 >;
use File::Basename 'basename';
use Mojo::UserAgent;
use URI;
use DBI;
use Getopt::Long;

my %args = ( charset => "UTF-8" );
GetOptions(
    \%args,
    "charset=s"
);

@ARGV == 3 or die;
my ($dbpath, $url, $selector) = @ARGV;

my $ua = Mojo::UserAgent->new;
my $tx = $ua->build_tx( GET => $url );
if ( $args{charset} ne "UTF-8" ) {
    $tx->res->on(
        finish => sub {
            my ($res) = @_;
            my $ct = $res->headers->header('Content-Type');
            $ct =~ s/;.*//;
            $res->headers->header('Content-Type' => "$ct; charset=$args{charset}");
        }
    );
}
$ua->start($tx);

die "download failed. ".(join(":",$tx->error->{code}, $tx->error->{message})) unless $tx->success;

my %seen;
my $order = 0;

my $resdom = $tx->res->dom;
for my $e ($resdom->find($selector)->each) {
    for my $e2 ( $e, $e->find("*[href]")->each ) {
        my $u = URI->new_abs( $e2->attr("href"), $url );
        $e2->attr(href => $u);
    }
    my $content = $e->to_string;
    my $digest = sha1_hex( encode_utf8($content) );
    $seen{$digest} = {
        order => $order++,
        body => $content,
    };
}

my $dbh = DBI->connect("dbi:SQLite:dbname=$dbpath", "", "");
my $SQL_NOW = q{ strftime('%Y-%m-%dT%H:%M:%SZ', 'now') };
$dbh->begin_work;
for my $sha1 (keys %seen) {
    my $row = $dbh->selectrow_arrayref("SELECT 1 FROM seen WHERE `sha1` = ?", {} , $sha1);
    if ($row) {
        $dbh->do("UPDATE seen SET `last_seen` = $SQL_NOW WHERE `sha1` = ?", {}, $sha1);
    }
    else {
        $dbh->do("INSERT INTO seen(`sha1`,`body`,`order`,`first_seen`) VALUES(?,?,?, $SQL_NOW)", {}, $sha1, $seen{$sha1}->{body}, $seen{$sha1}->{order});
    }
}

$dbh->do("UPDATE runlog SET `finished` = $SQL_NOW WHERE `program` = ?", {}, basename($0));
$dbh->commit;

__END__

perl collect-html-diff.pl congress-text-live.sqlite3 http://congress-text-live.herokuapp.com/ 'section.entry'
