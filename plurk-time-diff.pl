#!/usr/bin/env perl
use v5.18;

use FindBin;
use lib "${FindBin::Bin}/lib";
use PlurkPoster;

@ARGV == 3 or die;
binmode STDOUT, ":utf8";

my $plurk_secret = $ARGV[0];
my $begin_timestamp = $ARGV[1];
my $sprintf_template = Encode::decode_utf8($ARGV[2]);
my $time_diff_in_hour = int( (time - $begin_timestamp) / 3600);

my $message = sprintf($sprintf_template, $time_diff_in_hour);

open my $fh, "<", $plurk_secret;
my ($user, $pass, $hashtag);
chomp($user = <$fh>);
chomp($pass = <$fh>);
chomp($hashtag = <$fh>);
close($fh);

eval {
    my $bot = PlurkPoster->new(
        username => $user,
        password => $pass,
        hashtag  => $hashtag,
    );
    $bot->login;

    my $id = $bot->post($message);
    say "DEBUG: plurk id = $id";
    1;
} or do {
    say "=== SOME ERROR Happened: $@";
};
