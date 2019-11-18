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

@ARGV == 0 or die;

my $_payload = do { local $/; <STDIN> };
my $payload = JSON::PP->new->utf8->decode($_payload);

my @to_post;

my @news = sort { $a->{text} cmp $b->{text} } grep { $_->{text} } @{$payload->{news}};

$news[0]{_squash_text_length} = length($news[0]{text});
for (my $i = 1; $i < @news; $i++) {
    my $len = $news[$i-1]{_squash_text_length} + length($news[$i]{text});
    if ((substr($news[$i-1]{text}, 0, 2) eq substr($news[$i]{text}, 0, 2)) && ($len < 200)) {
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

for my $message (@to_post) {
    say $message;
    say '-' x (($ENV{COLUMNS} || 80) - 2);
}
