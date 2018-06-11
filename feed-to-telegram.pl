#!/usr/bin/env perl
use v5.26;
use strict;
use warnings;

use JSON::PP;
use Mojo::DOM;

use TelegramPoster;

@ARGV == 1 or die;

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

my $_secret = $ARGV[0];
my $secret = do {
    local $/;
    open my $fh, "<", $_secret;
    JSON::PP->new->utf8->decode(scalar <$fh>);
};
my $bot = TelegramPoster->new(
    token   => $secret->{token},
    chat_id => $secret->{chat_id},
);

for my $message (@to_post) {
    $bot->post($message);
    sleep 5;
}
