#!/usr/bin/env perl
use v5.26;
use strict;
use warnings;

use JSON::PP;
use Getopt::Long 'GetOptions';
use Encode 'encode_utf8';
use Mojo::UserAgent;

my %opts;
GetOptions(
    \%opts,
    "token=s",
);

my $feed_url = $ARGV[0] or die "A feed URL is required.";

my $_payload = do { local $/; <STDIN> };
my $payload = JSON::PP->new->utf8->decode($_payload);

my @to_post;

my @news = sort { $a->{text} cmp $b->{text} } grep { $_->{text} } @{$payload->{news}};

for my $entry (@news) {
    my $url = $entry->{first_link} // '';
    my $prefix = $entry->{prefix} // '';
    my $suffix = $entry->{suffix} // '';
    my $text = $entry->{text};
    my $title = substr($text, 0, 20) . "...";

    push @to_post, {
        $url ? (
            url => $url,
        ): (),
        title => $title,
        content_text => $entry->{text},
    };
}

$feed_url =~ s{\.json}{/items};
my $ua = Mojo::UserAgent->new;
for my $item (@to_post) {
    my $tx = $ua->post(
        $feed_url,
        { Authentication => "Bearer $opts{token}" },
        json => $item,
    );
    my $res = $tx->result;
    if ($res->is_error) {
        say "Error: " . $res->message;
    } elsif ($res->is_success) {
        say 'Success';
    } else {
        say "Not sure what happened... Response:";
        say $res->code;
        say $res->body;
    }
}
