#!/usr/bin/env perl
use v5.14;
use strict;
use warnings;

use File::Basename 'basename';
use Digest::SHA1 'sha1_hex';
use Encode ();
use DBI;

use FindBin;
use lib "${FindBin::Bin}/lib";
use TelegramPoster;

@ARGV == 2 or die;
binmode STDOUT, ":utf8";

my $program_name = basename($0);
say "DEBUG: program_name = $program_name";

my ($dbpath, $secret) = @ARGV;

my $lockfile = "/tmp/lock_" . sha1_hex(join(";",$0,$dbpath,$secret));
if (-f $lockfile) {
    say "DEBUG: locked. skip this run";
    exit;
}

open(my $fh, ">", $lockfile) or die $!;
say $fh $$;
close($fh);

my @news;

my $SQL_NOW = q{ strftime('%Y-%m-%dT%H:%M:%SZ', 'now') };
my $dbh = DBI->connect("dbi:SQLite:dbname=$dbpath", "", "");
my $row = $dbh->selectrow_arrayref("select finished FROM runlog WHERE program = ?", {}, $program_name);
if ($row) {
    say "DEBUG: Last run was finished at $row->[0]";
    my $rows = $dbh->selectall_arrayref("select body FROM seen WHERE first_seen > ? ORDER BY first_seen ASC, `order` DESC", {}, $row->[0]);
    for (@$rows) {
        my $body = Encode::decode_utf8($_->[0]);
        my $prefix = substr($body, 0, 40) . '%';

        my $similar_stuff = $dbh->selectrow_arrayref("SELECT count(sha1) FROM seen WHERE body like ?", {}, $prefix);
        unless ( $similar_stuff->[0] > 1 ) {
            push @news, $body;
        }
    }

}

$dbh->do("UPDATE runlog SET `finished` = $SQL_NOW WHERE `program` = ?", {}, $program_name);
$dbh->disconnect;

say "DEBUG: " . scalar(@news) . " new entries to post";

push @news, "Nihao";
if (@news) {
    open my $fh, "<", $secret;
    my ($token, $chat_id);
    chomp($token = <$fh>);
    chomp($chat_id = <$fh>);

    my $bot = TelegramPoster->new(
        token   => $token,
        chat_id => $chat_id,
    );

    eval {
        while (@news) {
            my $text = pop @news;
            $bot->post($text);
            sleep 10;
        }
        say "=== ALL POSTED";
        1;
    } or do {
        say "=== SOME ERROR Happened: $@";
    };
} else {
    say "=== NOTHING TO POST";
}

unlink($lockfile);

