package TelegramPoster;
use v5.14;
use WWW::Telegram::BotAPI;

sub new {
    my $class = shift;
    my %args  = @_;
    my $bot = WWW::Telegram::BotAPI->new (token => $args{token});
    return bless { bot => $bot, chat_id => $args{chat_id} }, $class;
}

sub post {
    my ($self, $content) = @_;

    $self->{bot}->api_request(
        sendMessage => {
            chat_id => $self->{chat_id},
            text    => $content
        }, sub {
            my ($ua, $tx) = @_;
            return unless $tx->success;
        }
    );
}

1;
