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

my %deduped;
for (@{$payload->{news}}) {
    my $html = $_->{body};
    my $dom = Mojo::DOM->new($html);

    my $text = $dom->all_text;  # space-trimmed.
    $text =~ s/\n\n+/\n/gs;
    $text =~ s/[ \t\n]+/ /gs;

    my $links = $dom->find("a")->map(attr => "href")->join(" ");
    if (exists $deduped{$links}) {
        if ($text && !$deduped{$links}) {
            $deduped{$links} = $text;
        }
    } else {
        $deduped{$links} = $text;
    }
}

my @to_post;
while (my ($url, $text) = each %deduped) {
    next if length($text) < 7;
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
