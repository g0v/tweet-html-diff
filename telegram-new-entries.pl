#!/usr/bin/env perl
use v5.14;
use strict;
use warnings;

use File::Basename 'basename';
use Digest::SHA1 'sha1_hex';
use Encode ();
use DBI;
use Mojo::DOM;

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
        push @news, $body;
    }
}

$dbh->do("UPDATE runlog SET `finished` = $SQL_NOW WHERE `program` = ?", {}, $program_name);
$dbh->disconnect;

say "DEBUG: " . scalar(@news) . " new entries to post";

if (@news) {
    open my $fh, "<", $secret;
    my ($token, $chat_id);
    chomp($token = <$fh>);
    chomp($chat_id = <$fh>);

    my $bot = TelegramPoster->new(
        token   => $token,
        chat_id => $chat_id,
    );

    my %deduped;
    eval {
        while (@news) {
            my $html = pop @news;
            my $dom = Mojo::DOM->new($html);

            my $text = $dom->all_text; # space-trimmed.
            my $links = $dom->find("a")->map(attr => "href")->join(" ");
            if (exists $deduped{$links}) {
                if ($text && !$deduped{$links}) {
                    $deduped{$links} = $text;
                }
            } else {
                $deduped{$links} = $text;
            }
        }

        my %posted;
        while (my ($links, $text) = each %deduped) {
            my $message = "$text $links";
            unless ($posted{$message}) {
                $bot->post($message);
                $posted{$message} = 1;
            }
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

