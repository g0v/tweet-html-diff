#!/usr/bin/env perl
use v5.14;
use strict;
use warnings;
use Digest::SHA1 'sha1_hex';
use Encode 'encode_utf8';
use File::Basename 'basename';
use Mojo::UserAgent;
use DBI;

@ARGV == 2 or die;
my ($dbpath, $url) = @ARGV;

my $ua = Mojo::UserAgent->new;
my $tx = $ua->get($url);
die "download failed" unless $tx->success;

my %seen;
my $order = 0;
for my $text_content (split /\r?\n/, $tx->res->body) {
    $text_content =~ s/^\s+//;
    $text_content =~ s/\s+$//;

    my $digest = sha1_hex( encode_utf8($text_content) );
    $seen{$digest} = {
        order => $order++,
        body => $text_content,
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

cat init.sql | sqlite3 fumao-text-live.sqlite3

perl collect-text-diff.pl fumao-text-live.sqlite3 https://ethercalc.org/static/proxy/live.txt

