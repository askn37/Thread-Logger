# $Id: Makefile.PL 3 2017-03-03 08:30:20Z askn $
use inc::Module::Install;
use version;

name 'Thread-Logger';
version_from 'lib/Thread/Logger.pm';
license 'perl';

requires 'perl' => '5.014';
requires 'threads' => '0';
requires 'threads::shared' => '0';
requires 'Encode' => '0';
requires 'Thread::Queue' => '0';
requires 'IO::Handle' => '0';
requires 'Carp' => '0';
requires 'Scalar::Util' => '0';
requires 'Time::HiRes' => '0';

# syslog unit
requires 'MIME::Base64' => '0';
requires 'Sys::Hostname' => '0';
requires 'IO::Socket::IP' => '0';

build_requires 'Test::More';

WriteAll;
