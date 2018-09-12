package TelegramPoster;
use v5.14;
use strict;
use warnings;
use WWW::Telegram::BotAPI;

sub new {
    my $class = shift;
    my %args  = @_;
    my $bot = WWW::Telegram::BotAPI->new( token => $args{token});
    my $tx = $bot->api_request('getMe');
    $tx = $bot->api_request('getUpdates', { offset => 0 });

    return bless { bot => $bot, chat_id => $args{chat_id} }, $class;
}

sub sendMessage {
    my ($self, $payload) = @_;
    $self->{bot}->api_request(
        sendMessage => {
            %$payload,
            chat_id => $self->{chat_id},
        }
    );
    return $self;
}

sub post {
    my ($self, $content) = @_;
    say "POSTING << $content";
    $self->{bot}->api_request(
        sendMessage => {
            parse_mode => "Markdown",
            chat_id => $self->{chat_id},
            text    => $content
        }
    );
    return $self;
}

1;
