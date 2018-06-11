#!/usr/bin/env perl
use v5.26;
use strict;
use warnings;

use JSON::PP;
use Mojo::DOM;
use Mastodon::Client;

@ARGV == 1 or die;

my $_mastodon_secret = $ARGV[0];
my $mastodon_secret = do {
    local $/;
    open my $fh, "<", $_mastodon_secret;
    JSON::PP->new->utf8->decode(scalar <$fh>);
};

my $_payload = do { local $/; <STDIN> };
my $payload = JSON::PP->new->utf8->decode($_payload);

my @to_post;

for my $entry (@{$payload->{news}}) {
    my $url = $entry->{first_link};
    my $text = $entry->{text};
    next unless length($text) > 7;
    
    my $message = "$url\n\n$text";
    push @to_post, $message;
}

my $client = Mastodon::Client->new(
    instance        => $mastodon_secret->{instance},
    name            => $mastodon_secret->{name},
    client_id       => $mastodon_secret->{client_id},
    client_secret   => $mastodon_secret->{client_secret},
    access_token    => $mastodon_secret->{access_token},
    coerce_entities => 1,
);

for my $text (@to_post) {
    $client->post_status(
        $text,
        { visibility => 'unlisted' }
    );
    sleep 1;
}
