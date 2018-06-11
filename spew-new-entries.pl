#!/usr/bin/env perl
use v5.18;
use strict;
use warnings;

use File::Basename 'basename';
use Digest::SHA1 'sha1_hex';
use Encode 'decode_utf8';
use DBI;
use JSON::PP;
use Mojo::DOM;

@ARGV == 2 or die;
my ($dbpath, $queue_name) = @ARGV;

my $lockfile = "/tmp/lock_" . sha1_hex(join(";",$0,$dbpath,$queue_name));
if (-f $lockfile) {
    say STDERR "DEBUG: locked. skip this run";
    exit;
}

open(my $fh, ">", $lockfile) or die $!;
say $fh $$;
close($fh);

my @news;

my $SQL_NOW = q{ strftime('%Y-%m-%dT%H:%M:%SZ', 'now') };
my $dbh = DBI->connect("dbi:SQLite:dbname=$dbpath", "", "");

my $time_previous_run;
my $row = $dbh->selectrow_arrayref("select finished FROM runlog WHERE program = ?", {}, $queue_name);
if ($row) {
    $time_previous_run = $row->[0];
} else {
    $dbh->do("INSERT INTO runlog(`program`) VALUES (?)", {}, $queue_name);
    $time_previous_run = "1970-01-01T00:00:00Z";
}

my $rows = $dbh->selectall_arrayref("select body,last_seen FROM seen WHERE first_seen > ? ORDER BY first_seen ASC, `order` DESC", {}, $time_previous_run);
for (@$rows) {
    my $body = decode_utf8($_->[0]);
    my $last_seen = $_->[1];
    push @news, {
        last_seen => $last_seen,
        body => $body
    };
}

$dbh->do("UPDATE runlog SET `finished` = $SQL_NOW WHERE `program` = ?", {}, $queue_name);
$dbh->disconnect;

unlink($lockfile);

my %deduped;
for my $entry (@news) {
    my $html = $entry->{body};
    my $dom = Mojo::DOM->new($html);

    my $text = $dom->all_text;  # space-trimmed.
    $text =~ s/\n\n+/\n/gs;
    $text =~ s/[ \t\n]+/ /gs;

    my @links = @{ $dom->find("a")->map(attr => "href")->to_array };
    my $links_str = join(" ", @links);

    $entry->{first_link} = $links[0];
    $entry->{links} = \@links;
    $entry->{text} = $text;

    unless (exists $deduped{$links_str}) {
        $deduped{$links_str} = $entry;
    }
}
@news = values %deduped;

say JSON::PP->new->utf8->encode({
    news => \@news
});
