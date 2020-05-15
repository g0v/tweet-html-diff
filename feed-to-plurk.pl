#!/usr/bin/env perl
use v5.26;
use strict;
use warnings;
use charnames ':full';

use List::Util qw(sum0);
use JSON::PP;
use Mojo::DOM;
use Getopt::Long 'GetOptions';
use OAuth::Lite::Consumer;
use OAuth::Lite::Token;
use Encode 'encode_utf8';

use StringUtils qw(take_front_keyword take_back_keyword);

# main
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

my %news_bucket;
for my $entry (grep { defined($_->{text}) && $_->{text} =~ m/\p{Letter}/ } @{$payload->{news}}) {
    my $keyword = take_front_keyword($entry->{text});
    push @{$news_bucket{$keyword}}, $entry;
}

for my $k (keys %news_bucket) {
    if (@{$news_bucket{$k}} == 1) {
        my $entry = $news_bucket{$k}[0];
        delete($news_bucket{$k});
        my $k2 = take_back_keyword( $entry->{text} );
        push @{$news_bucket{$k2}}, $entry;
    }
}

for my $k (grep { @{$news_bucket{$_}} == 1 } keys %news_bucket) {
    my $entry = $news_bucket{$k}[0];
    delete $news_bucket{$k};
    push @{$news_bucket{"0"}}, $entry;
}

my @sub_buckets;
for my $k (keys %news_bucket) {
    my $bucket = $news_bucket{$k};
    next if sum0(map { length($_->{text}) } @$bucket) <= 300;

    my @bucket2;
    my $length_bucket2 = 0;
    my $i = 0;
    while (sum0(map { length($_->{text}) } @$bucket) > 300) {
        my $entry = pop @$bucket;
        if (length($entry->{text}) + $length_bucket2 > 200) {
            push @sub_buckets, [ "$k:" . ($i++),  [@bucket2] ];
            @bucket2 = ();
        } else {
            push @bucket2, $entry;
            $length_bucket2 += length($entry->{text});
        }
    }
}
for my $x (@sub_buckets) {
    $news_bucket{$x->[0]} = $x->[1];
}

for my $k_bucket (keys %news_bucket) {
    my $bucket = $news_bucket{$k_bucket};
    my $msg = "";
    for my $entry (@$bucket) {
        my $url = $entry->{first_link} // '';
        my $prefix = $entry->{prefix} // '';
        my $suffix = $entry->{suffix} // '';
        my $text = $entry->{text};

        $text =~ s/\(/\x{FF08}/g;
        $text =~ s/\)/\x{FF09}/g;
        $msg .= "\n\n\N{BULLET} " . (
            $url
            ? join(" ", grep { $_ ne '' } ($prefix, ($url . ' (' . $text . ')'), $suffix))
            : join(" ", grep { $_ ne '' } ($prefix, $text, $suffix))
        );
    }
    next unless $msg;
    if (@$bucket == 1) {
        $msg =~ s/\A\n\n\N{BULLET} //s;
    } else {
        $msg =~ s/\A\n\n//s;
    }
    push @to_post, encode_utf8($msg);
}

if ($opts{n}) {
    for my $message (@to_post) {
        print "$message\n--------\n";
    }
    exit(0);
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
        method => 'POST',
        url => 'https://www.plurk.com/APP/Timeline/plurkAdd',
        token => $access_token,
        params => {
            content => $message,
            qualifier => ':',
        }
    );

    sleep $opts{sleep} if $opts{sleep};
}
