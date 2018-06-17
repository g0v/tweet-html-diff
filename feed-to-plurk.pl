#!/usr/bin/env perl
use v5.26;
use strict;
use warnings;

use JSON::PP;
use Mojo::DOM;
use Getopt::Long 'GetOptions';
use OAuth::Lite::Consumer;
use OAuth::Lite::Token;
use Encode 'encode_utf8';

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
    my $url = $entry->{first_link} // '';
    my $text = $entry->{text} // '';
    next unless length($text) > 7;

    my $prefix = $entry->{prefix} // '';
    my $suffix = $entry->{suffix} // '';
    push @to_post, encode_utf8 join("\n\n", grep { $_ ne '' } $prefix, $text, $url, $suffix);
}

my $auth = OAuth::Lite::Consumer->new(
    consumer_key    => $secret->{consumer_key},
    consumer_secret => $secret->{consumer_secret},
    access_token    => $secret->{consumer_key},
    site           => 'https://www.plurk.com',
);
my $access_token = OAuth::Lite::Token->new(
    token => $secret->{access_token},
    secret => $secret->{access_token_secret},
);

for my $message (@to_post) {
    my $res = $auth->request(
        method => 'GET',
        url => 'https://www.plurk.com/APP/Timeline/plurkAdd',
        token => $access_token,
        params => {
            content => $message,
            qualifier => ':',
        }
    );

    sleep $opts{sleep} if $opts{sleep};
}
