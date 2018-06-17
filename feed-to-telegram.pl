#!/usr/bin/env perl
use v5.26;
use strict;
use warnings;

use JSON::PP;
use Mojo::DOM;
use Getopt::Long 'GetOptions';

use TelegramPoster;

my %opts;
GetOptions(
    \%opts,
    "sleep=n",
);
$opts{sleep}  //= 5;

@ARGV == 1 or die;

my $_secret = $ARGV[0];
my $secret = do {
    local $/;
    open my $fh, "<", $_secret;
    JSON::PP->new->utf8->decode(scalar <$fh>);
};

my $_payload = do { local $/; <STDIN> };
my $payload = JSON::PP->new->utf8->decode($_payload);

my @to_post;

for my $entry (@{$payload->{news}}) {
    my $url = $entry->{first_link};
    my $text = $entry->{text} // '';
    next unless length($text) > 0;

    my $prefix = $entry->{prefix} // '';
    my $suffix = $entry->{suffix} // '';
    push @to_post, join("\n\n", grep { $_ ne '' } $prefix, $text, $url, $suffix);
}

my $bot = TelegramPoster->new(
    token   => $secret->{token},
    chat_id => $secret->{chat_id},
);

for my $message (@to_post) {
    $bot->post($message);
    sleep $opts{sleep} if $opts{sleep};
}
