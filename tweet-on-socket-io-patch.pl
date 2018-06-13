use strict;
use warnings;
use AnyEvent;
use PocketIO::Client::IO;

use YAML;

my $cv = AnyEvent->condvar;

my $socket = PocketIO::Client::IO->connect("http://congress-text-live.herokuapp.com/");

$socket->on('msg', sub {
                say $_[1];
            });
 
$socket->on('patch', sub {
                print YAML::Dump(\@_);
            } );
 
$cv->wait;
