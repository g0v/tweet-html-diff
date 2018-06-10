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
