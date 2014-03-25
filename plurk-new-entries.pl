#!/usr/bin/env perl
use v5.14;
use strict;
use warnings;

package PlurkPoster;
use Data::Dumper;
use Mojo::UserAgent;

sub new {
    my $class = shift;
    return bless { @_ }, $class;
}

sub login {
    my ($self) = @_;
    $self->{ua} = Mojo::UserAgent->new;
    $self->{ua}->on(
        "start",
        sub {
            my ($ua, $tx) = @_;
            my $headers = $tx->req->headers;
            $headers->remove("Accept-Encoding");
            $headers->header("User-Agent", "Mozilla/5.0 (iPhone; U; CPU like Mac OS X; en) AppleWebKit/420+ (KHTML, like Gecko) Version/3.0 Mobile/1A543 Safari/419.3");
            sleep 1;
        }
    );

    my $tx = $self->{ua}->get('https://www.plurk.com/m/login');
    die "failed 1" unless $tx->success;

    $tx = $self->{ua}->post('https://www.plurk.com/m/login' => form => { username => $self->{username}, password => $self->{password} });
    die "failed 2" unless $tx->success;

    return $self;
}

sub post {
    my ($self, $content) = @_;
    my $ua = $self->{ua};

    my @content;
    if ( length($content) < 120 ) {
        @content = ($content);
    }
    else {
        my $pieces = int(length($content) / 120);
        for (0 .. $pieces) {
            push @content, substr($content, 120 * $_, 120);
        }
        for (1..$#content-1) {
            $content[$_] = "... $content[$_] ...";
        }
        $content[0] .= "...";
        $content[-1] = "... $content[-1]";
    }

    my $text = shift @content;
    $text .= " $self->{hashtag}" if $self->{hashtag};

    my $tx = $ua->get('http://www.plurk.com/m/');
    die "failed 3" unless $tx->success;

    my $user_id = $tx->res->dom("input[name=user_id]")->attr("value");

    $tx = $ua->post('http://www.plurk.com/m/' => form => {
        user_id => $user_id,
        language => "en",
        qualifier => ":",
        content =>  $text,
    });
    die "failed 4" unless $tx->success;
    say ">>> $text";

    $tx = $ua->get('http://www.plurk.com/m/?mode=my');
    die "failed 5" unless $tx->success;

    my $link_to_plurk = $tx->res->dom->find("div.plurk a.r")->[0];
    my ($plurk_id) = $link_to_plurk->attr("href") =~ m{/m/p/(.+)$};
    my $plurk_permaurl = "http://www.plurk.com/" . $link_to_plurk->attr("href");

    say "DEBUG: plurk = $plurk_permaurl";
    while (@content) {
        my $text = shift @content;

        $tx = $ua->get($plurk_permaurl);
        die "failed 5" unless $tx->success;

        say "RE> $text";
        $tx = $ua->post("${plurk_permaurl}/#plurkbox" => form => {
            user_id => $user_id,
            language => "en",
            qualifier => ":",
            content => $text,
        });
        die "failed 6" unless $tx->success;
    }

    return $plurk_id;
}

package main;
use File::Basename 'basename';
use Encode ();
use DBI;

@ARGV == 2 or die;
binmode STDOUT, ":utf8";

my ($dbpath, $plurk_secret) = @ARGV;
my @news;

my $SQL_NOW = q{ strftime('%Y-%m-%dT%H:%M:%SZ', 'now') };
my $dbh = DBI->connect("dbi:SQLite:dbname=$dbpath", "", "");
my $row = $dbh->selectrow_arrayref("select finished FROM runlog WHERE program = ?", {}, basename($0));
if ($row) {
    my $rows = $dbh->selectall_arrayref("select body FROM seen WHERE last_seen is NULL OR last_seen > ? ORDER BY first_seen ASC", {}, $row->[0]);
    for (@$rows) {
        my $body = Encode::decode_utf8($_->[0]);
        push @news, $body;
    }
}

$dbh->do("UPDATE runlog SET `finished` = $SQL_NOW WHERE `program` = ?", {}, basename($0));

if (@news) {
    say "DEBUG: " . scalar(@news) . " new entries to plurk";

    open my $fh, "<", $plurk_secret;
    my ($user, $pass, $hashtag);
    chomp($user = <$fh>);
    chomp($pass = <$fh>);
    chomp($hashtag = <$fh>);

    my $bot = PlurkPoster->new(
        username => $user,
        password => $pass,
        hashtag  => $hashtag,
    );
    $bot->login;

    while (@news) {
        my $text = pop @news;
        my $id = $bot->post($text);
        say "DEBUG: plurk id = $id";
    }
}
