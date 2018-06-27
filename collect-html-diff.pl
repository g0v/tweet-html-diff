#!/usr/bin/env perl
use v5.14;
use strict;
use warnings;
use Digest::SHA1 'sha1_hex';
use Encode qw< decode decode_utf8 encode_utf8 >;
use File::Basename 'basename';
use Mojo::UserAgent;
use URI;
use DBI;
use Getopt::Long;

my %args = ( charset => "UTF-8" );
GetOptions(
    \%args,
    "charset=s",
    "prefix=s",
    "suffix=s",
);
$args{prefix} = decode_utf8( $args{prefix} // '');
$args{suffix} = decode_utf8( $args{suffix} // '');

@ARGV == 3 or die;
my ($dbpath, $url, $selector) = @ARGV;

my $ua = Mojo::UserAgent->new;
$ua->connect_timeout(30);
$ua->request_timeout(30);
$ua->inactivity_timeout(30);

my $tx = $ua->build_tx( GET => $url );
if ( $args{charset} ne "UTF-8" ) {
    $tx->res->on(
        finish => sub {
            my ($res) = @_;
            my $ct = $res->headers->header('Content-Type');
            $ct =~ s/;.*//;
            $res->headers->header('Content-Type' => "$ct; charset=$args{charset}");

            my $body_new = decode($args{charset}, $tx->res->body);
            $tx->res->body($body_new);
        }
    );
}
$ua->start($tx);

die "download failed. url=${url} ".(join(":",$tx->error->{code} // '(unknown code)', $tx->error->{message} //'(unknonw message)')) unless $tx->success;

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
        $dbh->do("INSERT INTO seen(`sha1`,`body`,`order`,`first_seen`, `prefix`, `suffix`) VALUES(?,?,?, $SQL_NOW, ?,?)", {}, $sha1, $seen{$sha1}->{body}, $seen{$sha1}->{order}, $args{prefix}//'', $args{suffix}//'');
    }
}

my $program = basename($0);
my $row = $dbh->selectrow_arrayref('SELECT 1 FROM runlog WHERE program = ?', {}, $program);
if ($row) {
    $dbh->do("UPDATE runlog SET `finished` = $SQL_NOW WHERE `program` = ?", {}, $program);
} else {
    $dbh->do("INSERT INTO runlog(`program`, `finished`) VALUES(?, $SQL_NOW)", {}, $program);
}
$dbh->commit;

__END__

perl collect-html-diff.pl congress-text-live.sqlite3 http://congress-text-live.herokuapp.com/ 'section.entry'
