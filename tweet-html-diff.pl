#!/usr/bin/env perl
use v5.14;
use strict;
use warnings;
use Digest::SHA1 'sha1_hex';
use Encode 'encode_utf8';
use Mojo::UserAgent;
use Net::Twitter;
use DBI;

@ARGV >= 4 or die;
my ($dbpath, $url, $selector, $twitter_secret_file, $hashtag) = @ARGV;

$hashtag = $hashtag  ? " $hashtag" : "";

my $ua = Mojo::UserAgent->new;
my $tx = $ua->get($url);
die "download failed" unless $tx->success;

my @news;
my %seen;
for my $e ($tx->res->dom->find($selector)->each) {
    my $text_content = $e->all_text;
    my $digest = sha1_hex( encode_utf8($text_content) );
    $seen{$digest} = $text_content;
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
        push @news, $seen{$sha1};
        $dbh->do("INSERT INTO seen(`sha1`,`body`,`first_seen`) VALUES(?,?, $SQL_NOW)", {}, $sha1, $seen{$sha1});
    }
}
$dbh->commit;

binmode STDOUT, ":utf8";
for (@news) {
    print "$_\n\n";
}

if (-f $twitter_secret_file) {
    open(my $fh, "<", $twitter_secret_file) or die "failed to open $twitter_secret_file";
    my ($consumer_key, $consumer_secret, $access_token, $access_token_secret);
    chomp($consumer_key = <$fh>);
    chomp($consumer_secret = <$fh>);
    chomp($access_token = <$fh>);
    chomp($access_token_secret = <$fh>);

    my $nt = Net::Twitter->new(
        traits   => [qw/API::RESTv1_1/],
        consumer_key        => $consumer_key,
        consumer_secret     => $consumer_secret,
        access_token        => $access_token,
        access_token_secret => $access_token_secret,
        ssl => 1,
    );

    for my $text (@news) {
        eval {
            $nt->update( $text . $hashtag );
            sleep 3;
            say ">>> $text";
            1;
        } or do {
            say "ERROR: $@";
            say "!!! $text";
        };
    }
}

__END__

CREATE TABLE seen (`sha1` VARCHAR(40), `body` TEXT, `first_seen` DATETIME, `last_seen` DATETIME, PRIMARY KEY (`sha1`));

perl tweet-html-diff.pl congress-text-live.sqlite3 http://congress-text-live.herokuapp.com/ 'section.entry' twitter_secret
