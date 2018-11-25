use strict;
use warnings;
use utf8;
use threads;
use threads::shared;

use Test::More tests => 7;

# Test:1
BEGIN {
	use_ok 'Thread::Logger';
}

use Thread::Logger;
my $result;

# Test:2
my $logger = Thread::Logger->new;
isa_ok $logger, 'Thread::Logger';

# Test:3
$logger->inherit(Name => 'Test');
is $logger->{Name}, 'Test';

# Test:4
async {
	$logger->logs('Logging');
}->join;
like $logger->{_LOGGER}{queue}[-1][-1], qr/^Test\[$$:1\]: Logging$/;

# Test:5
async {
	$logger->logf('%s', 'Logging');
}->join;
like $logger->{_LOGGER}{queue}[-1][-1], qr/^Test\[$$:2\]: Logging$/;

# Test:6
async {
	$logger->logdump('Logging');
}->join;
like $logger->{_LOGGER}{queue}[-1][-1], qr/^Test\[$$:3\]: 'Logging'$/;

# Test:7
$result = $logger->logflush;
isa_ok $result, 'Thread::Logger';

