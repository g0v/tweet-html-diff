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
    "prefix=s",
    "suffix=s",
    "sleep=n",
);
$opts{sleep}  //= 5;
$opts{prefix} //= '';
$opts{suffix} //= '';
$opts{prefix} =~ s/\n*\z/\n\n/;
$opts{suffix} =~ s/\A\n*/\n\n/;

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
    next unless length($text) > 7;

    my $message = $opts{prefix} . "$text\n\n$url" . $opts{suffix};
    push @to_post, $message;
}

my $bot = TelegramPoster->new(
    token   => $secret->{token},
    chat_id => $secret->{chat_id},
);

for my $message (@to_post) {
    $bot->post($message);
    sleep $opts{sleep} if $opts{sleep};
}
