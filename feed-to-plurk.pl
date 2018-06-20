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

my @news = sort { $a->{text} cmp $b->{text} } grep { $_->{text} } @{$payload->{news}};

$news[0]{_squash_text_length} = length($news[0]{text});
for (my $i = 1; $i < @news; $i++) {
    my $len = $news[$i-1]{_squash_text_length} + length($news[$i]{text});
    if ((substr($news[$i-1]{text}, 0, 3) eq substr($news[$i]{text}, 0, 3)) && ($len < 200)) {
        $news[$i]{_squash} = 1;
        $news[$i]{_squash_text_length} = $len;
    } else {
        $news[$i]{_squash} = 0;
        $news[$i]{_squash_text_length} = length($news[$i]{text});
    }
}

for my $entry (@news) {
    my $url = $entry->{first_link} // '';
    my $prefix = $entry->{prefix} // '';
    my $suffix = $entry->{suffix} // '';
    my $text = $entry->{text};

    if ($url) {
        # Converting half-width parenthesis to be full-width.
        # Because half-width parenthesis is used to label link.
        $text =~ s/\(/\x{FF08}/g;
        $text =~ s/\)/\x{FF09}/g;

        my $msg = encode_utf8 join(" ", grep { $_ ne '' } ($prefix, ($url . ' (' . $text . ')'), $suffix));
        if ($entry->{_squash}) {
            $to_post[-1] .= "\n\n" . $msg;
        }  else {
            push @to_post, $msg;
        }
    } else {
        my $msg = encode_utf8 join(" ", grep { $_ ne '' } ($prefix, $text, $suffix));
        if ($entry->{_squash}) {
            $to_post[-1] .= "\n\n" . $msg;
        }  else {
            push @to_post, $msg;
        }
    }
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
