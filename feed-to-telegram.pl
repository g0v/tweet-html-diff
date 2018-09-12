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
    "n|dry-run",
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
    if ($text && $url) {
        push @to_post, {
            parse_mode => "Markdown",
            text => join("\n\n", grep { $_ ne '' } $prefix, "[\x{1F517}OPEN\x{2197}]($url)" . " " . $text, $suffix),
        };
    } else {
        push @to_post, {
            parse_mode => "Markdown",
            text => join("\n\n", grep { $_ ne '' } $prefix, $text, $suffix),
        };
    }
}

my $bot = TelegramPoster->new(
    token   => $secret->{token},
    chat_id => $secret->{chat_id},
);

if ($opts{n}) {
    for my $message (@to_post) {
        print ">>> $message\n";
    }
    exit(0);
}

for my $message (@to_post) {
    $bot->sendMessage($message);
    sleep $opts{sleep} if $opts{sleep};
}
