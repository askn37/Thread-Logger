# $Id: Logger.pm 90 2018-11-25 05:56:46Z askn $
package Thread::Logger;
use Exporter 'import';
use strict;
use warnings;
use utf8;
use threads;
use threads::shared;
use Thread::Queue;
use Carp qw/croak/;
use Scalar::Util qw/openhandle/;
use Time::HiRes qw/gettimeofday/;

our $VERSION = '1.02_'. (q$Revision: 90 $ =~ /(\d+)/o, $1)[0];

=encoding utf8

=head1 NAME

Thread::Logger - Multi-thread logging stream helper

=head1 SYNOPSIS

    use Thread::Logger;

    my $Logger = Thread::Logger->new(
        Name    => 'Foo',
        Logfile => 'Foo_%s.log',
    );
    $Logger->logs('Start');

    use threads;
    async {
        $Logger->logs('abc', undef, 'def', "hij\nklm");
        $Logger->logf('nop %d %d', 1, 2);
        $Logger->logdump({qrs => 3});
    }->join;

    $Logger->logs('End');
    $Logger->logclose;

    Ex: Foo_20160404.log;

        2016/04/04 11:49:55.090 Foo[408] Start
        2016/04/04 11:49:55.096 Foo[408:1] abc
        2016/04/04 11:49:55.096 Foo[408:1] def
        2016/04/04 11:49:55.096 Foo[408:1] hij
        2016/04/04 11:49:55.096 Foo[408:1] klm
        2016/04/04 11:49:55.096 Foo[408:1] nop 1 2
        2016/04/04 11:49:55.096 Foo[408:1] {
        2016/04/04 11:49:55.096 Foo[408:1]   'qsr' => 3
        2016/04/04 11:49:55.096 Foo[408:1] }
        2016/04/04 11:49:55.099 Foo[408] End

=head1 DESCRIPTION

Logfile/Handle output for multi-thread is offered.

=cut

our @EXPORT_OK = qw{
    logopen logclose logdtsio logflush
    logs logf logdump logname logdate now
    logcodepage getcodepage facility priority
};
our %EXPORT_TAGS = (
    import => [@EXPORT_OK]
);
my %PRIORITIES = (
    emerg         => 0,
    emergency     => 0,
    alert         => 1,
    crit          => 2,
    critical      => 2,
    err           => 3,
    error         => 3,
    warning       => 4,
    notice        => 5,
    info          => 6,
    informational => 6,
    debug         => 7
);
my %FACILITIES = (
    kern      => 0,
    kernel    => 0,
    user      => 1,
    mail      => 2,
    daemon    => 3,
    system    => 3,
    auth      => 4,
    syslog    => 5,
    internal  => 5,
    lpr       => 6,
    printer   => 6,
    news      => 7,
    uucp      => 8,
    cron      => 9,
    clock     => 9,
    authpriv  => 10,
    security2 => 10,
    ftp       => 11,
    FTP       => 11,
    NTP       => 11,
    audit     => 13,
    alert     => 14,
    clock2    => 15,
    local0    => 16,
    local1    => 17,
    local2    => 18,
    local3    => 19,
    local4    => 20,
    local5    => 21,
    local6    => 22,
    local7    => 23,
);
sub new {
    my $class = shift;
    return bless {
        Name     => 'logger',
       #PeerHost => '127.0.0.1:514',
       #Syslog   => 'multiplex',    # of 1 rfc3194
        Facility => 'local7',
        Priority => 'debug',
        Codepage => getcodepage(),
        _LOGGER  => Thread::Queue->new,
        @_
    }, ref $class || $class || __PACKAGE__;
}
sub inherit {
    my $self = shift;
    if (1 == scalar @_ and ref $_[0] and $_[0]->{_LOGGER}) {
        my $parent = shift;
        %$self = (
           #PeerHost => '127.0.0.1:514',
            Facility => 'local7',
            Priority => 'debug',
            Codepage => $parent->{Codepage},
            Logfile  => $parent->{Logfile},
            Name     => ($parent->{Name} // $parent->{name} // 'logger'),
            %$self,
            @_
        );
        $self->{_LOGGER} = $parent->{_LOGGER} // Thread::Queue->new;
    }
    else {
        %$self = (
            %$self,
            @_
        );
        $self->{_LOGGER} = Thread::Queue->new;
    }
    return $self;
}
sub getcodepage {
    my $self = shift;
	my $get_oemcp = eval {
		local($SIG{__DIE__}, $@) = 'DEFAULT';
		require Win32::API;
		return Win32::API->new('kernel32', 'GetOEMCP', '', 'N');
	};
	my $cp = $get_oemcp && $get_oemcp->Call();
    return $cp && "CP" . $cp;
}
sub logcodepage {
    my $self = shift;
    $self->{Codepage} = shift if scalar @_;
    return $self->{Codepage};
}
sub logopen {
    my $self = shift;
    $self->{Logfile} //= *STDOUT;
    if (my $fh = openhandle $self->{Logfile}) {
        unless ($self->{_LOGH}) {
            $self->{_LOGGER}{_CP} = $self->{Codepage};
            open $self->{_LOGH}, '>&=', fileno($fh) or croak $!;
            $self->{_LOGH}->autoflush(1);
            $self->{_LOGF} = undef;
        }
    }
    else {
        my $logfile = logname($self);
        unless (-f $logfile) {
            if (defined $self->{_LOGH} and
                $self->{_LOGH}->opened and
                $self->{_LOGF} && -f $self->{_LOGF}) {
                $self->{_LOGH}->close;
                $self->{_LOGH} = undef;
            }
        }
        unless ($self->{_LOGH}) {
            $self->{_LOGGER}{_CP} = 'UTF-8';
            open $self->{_LOGH}, '>>', $logfile or croak $!;
            $self->{_LOGH}->autoflush(1);
            $self->{_LOGF} = $logfile;
        }
    }
    return $self;
}
sub logstdio {
    my $self = logopen(shift);
    if (defined $self->{_LOGH} and $self->{_LOGH}->opened) {
        foreach my $glob (@_) {
            open $glob, '>&=' . fileno($self->{_LOGH}) or croak $!;
            $glob->autoflush(1);
            $self->{_LOGF} = undef;
        }
    }
    return $self;
}
sub logclose {
    my $self = shift;
    logflush($self);
    if (defined $self->{_LOGH} and
        $self->{_LOGH}->opened and
        $self->{_LOGF} && -f $self->{_LOGF}) {
        $self->{_LOGH}->close;
        $self->{_LOGH} = undef;
    }
    return $self;
}
sub DESTROY {
    my $self = shift;
    $self->logclose unless defined $self->{_LOGGER}{_TID} and $self->{_LOGGER}{_TID};
}
sub logflush {
    my $self = shift;
    my $wait = shift // 0;
    $self->{_LOGGER}{_T} //= time;
    return $self if $wait and time < $self->{_LOGGER}{_T} + $wait;
    unless ($self->{_LOGGER}->pending) {
        if (defined $self->{_LOGH} and
            $self->{_LOGH}->opened and
            $self->{_LOGF} && -f $self->{_LOGF}) {
            $self->{_LOGH}->close;
            $self->{_LOGH} = undef;
        }
        return $self;
    }
    require Encode;
    if ($self->{Syslog}) {
        require IO::Socket::IP;
        require MIME::Base64;
        require Sys::Hostname;
        my($host, $port) = IO::Socket::IP->split_addr($self->{PeerHost} // "127.0.0.1:514");
        my $hostname = Encode::decode($self->{Codepage} // 'UTF-8', Sys::Hostname::hostname() // '');
        my $sock = IO::Socket::IP->new(
            PeerHost => ($host ||= "127.0.0.1"),
            PeerPort => $port || 514,
            Proto    => "udp"
        );
        if ($sock) {
            my $d = sprintf "<%d>",
                    ((($FACILITIES{$self->{Facility}} // 23) << 3)
                     | $PRIORITIES{$self->{Priority}} // 7);
            # MULTIPLEX
            if ($self->{Syslog} =~ /multiplex/io) {
                while ($self->{_LOGGER}->pending) {
                    my($now, $line) = @{$self->{_LOGGER}->dequeue_nb};
                    my $message = Encode::encode(UTF7 => $hostname . " " . $line);
                    $message =~ s/^\s+//o;
                    my($hex) = MIME::Base64::encode(pack("Q", $now), '') =~ /(.*?)A*=*$/o;
                    my $head = $d . $hex;
                    my $len = 1024 - 6 - length $head;
                    my @buffer = $message =~ /(.{1,$len})/gs;
                    my @output = splice @buffer, 0, 64;
                    my $count = (($$ & 0x3FFFF) << 12) | ((-1 + scalar @output) << 6);
                    while (my $line = shift @output) {
                        my $mark = substr MIME::Base64::encode(pack("N", $count++ << 2), ''), 0, 5;
                        $sock->send($head . $mark . "\t" . $line);
                    }
                }
            }
            # RFC 3194
            else {
                while ($self->{_LOGGER}->pending) {
                    my($now, $line) = @{$self->{_LOGGER}->dequeue_nb};
                    my $message = Encode::encode(UTF8 => $hostname . " " . $line);
                    $message =~ s/^\s+//o;
                    my $date = scalar localtime(int(($now // 0) / 1000) || time);
                    my($head) = $date =~ /(\w\w\w (?: \d|\d\d) \d\d:\d\d:\d\d)/o;
                    # 'msec'
                    if ($self->{Syslog} =~ /msec/io) {
                        $head .= sprintf ".%03d", $now % 1_000;
                    }
                    $sock->send($d . $head . " " . $message);
                }
            }
            $sock->close;
            return $self;
        }
        $self->logs("colud not send syslog: $!");
        delete $self->{Syslog};
    }
    while ($self->{_LOGGER}->pending) {
        logopen($self);
        eval {
            my($now, $line) = @{$self->{_LOGGER}->dequeue_nb};
            $now = logdate($self, $now) unless $now =~ /\D/o;
            $line = Encode::encode($self->{_LOGGER}{_CP} => $line) if $self->{_LOGGER}{_CP};
            $self->{_LOGH}->print($now, " ", $line, "\n");
        };
        $self->{_LOGGER}{_T} = time;
    }
    return $self;
}
sub logs {
    my $self = shift;
    my @output;
    my $tid = $self->{_LOGGER}{_TID} = threads->tid;
    my $pid = $tid ? sprintf('%s:%s', $$, $tid) : $$;
    my $name = $self->{Name} // $self->{name} // '';
    my $head = sprintf "%s[%s]: ", $name, $pid;
    foreach my $input (@_) {
        my $now = now();
        foreach my $line (split /\n/, ($input // '') ) {
            $line //= '';
            $line =~ s/\s+$//so;
            $line =~ tr/\0\x7f//d;
            push @output, [$now, $head . $line] if defined $input and length $input;
        }
    }
    $self->{_LOGGER}->enqueue(@output) if @output;
    return $self;
}
sub logf {
    my $self = shift;
    my $fmt = shift // '';
    my $eval = eval {
		local $SIG{__WARN__} = sub {carp $_[0]};
		sprintf $fmt, @_;
	};
	return logs($self, $eval);
}
sub logdump {
    my $self = shift;
    no warnings 'redefine';
	require Data::Dumper;
	local $Data::Dumper::Sortkeys = 1;
	local $Data::Dumper::Indent = 2;
	local $Data::Dumper::Terse = 1;
	local $Data::Dumper::Useperl = 1;
	local $Data::Dumper::Deparse = 0;
	local *Data::Dumper::qquote = sub {
		my $s = shift;
		$s =~ s/(['\\])/\\$1/go;
		return "'$s'";
	};
    return logs($self, Data::Dumper::Dumper(@_));
}
sub logname {
    my $self = shift;
    my @t = localtime;
    my $date = sprintf '%04u%02d%02d', $t[5] + 1900, $t[4] + 1, $t[3];
    return sprintf $self->{Logfile} // '', $date;
}
sub logdate {
    my $self = shift;
    my $now = shift // now();
    my @t = localtime int($now / 1_000);
    return sprintf '%04u/%02d/%02d %02d:%02d:%02d.%03d',
        $t[5] + 1900, $t[4] + 1,
        @t[3,2,1, 0],
        $now % 1_000;
}
sub now {
    my $self = shift;
    my($s, $u) = gettimeofday;
    return $s * 1_000 + int($u / 1_000);
};
sub facility {
    my $self = shift;
    my $label = shift;
    return $self->{Facility} unless defined $label;
    $self->{Facility} = exists $FACILITIES{$label} ? $label : 'local7';
    return $self;
}
sub priority {
    my $self = shift;
    my $label = shift;
    return $self->{Priority} unless defined $label;
    $self->{Priority} = exists $PRIORITIES{$label} ? $label : 'debug';
    return $self;
}

1;
__END__
=pod

=head1 CONSTRUCTOR OPTIONS

=over

=item new(key => value, ...)

Used only main-thread.

=over 12

=item C<Name>

aliases C<name>.

=item C<name>

The name character string included in log printout.
The default is ''.

=item C<Logfile>

Output Logfile name scalar or blessed opend IO::Handle object.

Default(empty) is output by *STDOUT.

Scalar string in '%s' is substituted for by DATE. (Ex: 20160404)

=item C<Codepage>

Output stream (Encode) codepage.
To file is UTF-8.

=back

=back

=head1 METHODS

=over

=item $Logger->logopen

Re/Open stream handle.
Used only main-thread.

=item $Logger->logstdio(*GLOB ...)

Redirect stream open to *GLOB.
Used only main-thread.

    $Logger = Thread::Logger->new()->logstdio(*STDOUT, *STDERR);

    print "STDOUT to log\n";
    warn 'STDERR to log';

NOTE; Data header string to stream no added.
NOTE; Not supported codepage.

=item $Logger->logs(@strings)

An enqueue arranges for an argument.
undef, empty string and a blank line are ignored.
The linefeed(\n) is sorted from a new paragraph.

=item $Logger->logf("FORMAT", @args)

Used by sprintf before logs().

=item $Logger->logdump(...)

Used by Data::Dumper->Dumper before logs().

=item $Logger->logflush(WaitSeconds)

Writing logfile.
Used only main-thread.
Setting C<WaitSeconds> is output buffer delay.

=item $Logger->logclose

close stream handle.

=item $logname = $Logger->logname

Return a log filename string.

=item $logdate = $Logger->logdate

Return a string DATE. (Ex: 20160404)

=item $msec = $Logger->now

Return a number representing the current time.
The unit is the millisecond. (1/1000 second)

Eq; C<jQuery.now()>, C<(new Date).getTime()>

=item $OtherObject->inherit(key => value, ...)

=item $OtherObject->inherit($Logger, key => value, ...)

Inheritance methods.
main-thread only.

=item $facility = $Logger->facility

=item $Logger = $Logger->facility(FACILITY)

Get/Set output syslog mode facility.
Default; 'local7'.

    kernel user mail system security internal printer
    news uucp clock security2 FTP NTP audit alert clock2
    local0 local1 local2 local3 local4 local5 local6 local7

=item $priority = $Logger->priority

=item $Logger = $Logger->priority(PRIORITY)

Get/Set output syslog mode priority.
Default; 'debug'.

    emergency alert crit critical err error warning
    notice info informational debug

=back

=head1 OBJECT PROPERTY

=over

=item $Logger->{Name}

=item $Logger->{name}

new(Name => '...');

=item $Logger->{Logfile}

new(Logfile => '...');

=item $Logger->{_LOGGER}

L<Thread::Queue>

=item $Logger->{_LOGH}

L<IO::Handle>

=item $Logger->{_LOGF}

=item $Logger->{_T}

=back

=head1 SYSLOG PROPERTY

=over

    my $Logger = Thread::Logger->new(
        Name     => 'Foo',
        Syslog   => 'rfc3194',
        PeerHost => '192.168.0.1:514',  # UDP only
        Facility => 'local7',
        Priority => 'info'
    );

=back

=head1 LOG FORMAT

=over

=item B<YYYY/MM/DD hh:mm:ss.sss NAME[PID:TID] String...>

The standard of time is the C<localtime()>.

=over 12

=item I<YYYY>

Year.

=item I<MM>

Month.

=item I<DD>

Day.

=item I<hh>

Hour.

=item I<mm>

Minute.

=item I<ss.sss>

Second and millisecond.

=item I<NAME>

Name string; new(name=>'String') setting.

=item I<PID>

Process ID.

Eq; $$

=item I<TID>

Threads ID.
Empty is main-thread.

Eq; threads::thread->tid

=back

=back

=head1 INHERITANCE EXAMPLE

=over

    # inheritance methods your module

    package MyModule;
    use Thread::Logger ':import'

    sub new {
        my $class = shift;
        $object = bless {}, ref $class || $class || __PACKAGE__;

        $object->Thread::Logger::inherit(
            Name => 'somename',
            Logfile => '/path/to/somename_%s.log',
            @_
        );
        return $object;
    }

    package main;
    use MyModule;

    my $object = MyModule->new();

    $object->logs('log text');
    $object->logflush;

=back

=head1 AUTHOR

朝日薫 / askn
Twitter: [@askn37](https://twitter.com/askn37)
GitHub: https://github.com/askn37

=head1 COPYRIGHT AND LICENSE

Copyright 2016 朝日薫 / askn

This library is free software; you may redistribute
it and/or modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<therads>,
L<Thread::Queue>,
L<Win32::Service::CLI>,
L<Win32::Service::Syslogd>

=cut
