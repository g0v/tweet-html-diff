package StringUtils;
use parent 'Exporter';

our @EXPORT_OK = qw(take_front_keyword);

sub take_front_keyword {
    my ($str) = @_;
    my @two_letters = $str =~ m/\A \P{Letter}* (\p{Letter}) \P{Letter}* (\p{Letter})/x;
    return join "", @two_letters;
}

1;
