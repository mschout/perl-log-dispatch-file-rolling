package Log::Dispatch::File::Rolling;

use 5.006001;
use strict;
use warnings;

use Log::Dispatch::File;
use Log::Log4perl::DateFormat;
use Fcntl ':flock'; # import LOCK_* constants

our @ISA = qw(Log::Dispatch::File);

our $VERSION = '1.01';

our $TIME_HIRES_AVAILABLE = undef;

BEGIN { # borrowed from Log::Log4perl::Layout::PatternLayout, Thanks!
	# Check if we've got Time::HiRes. If not, don't make a big fuss,
	# just set a flag so we know later on that we can't have fine-grained
	# time stamps
	
	eval { require Time::HiRes; };
	if ($@) {
		$TIME_HIRES_AVAILABLE = 0;
	} else {
		$TIME_HIRES_AVAILABLE = 1;
	}
}

# Preloaded methods go here.

sub new {
	my $proto = shift;
	my $class = ref $proto || $proto;
	
	my %p = @_;
	
	my $self = bless {}, $class;
	
	# only append mode is supported
	$p{mode} = 'append';
	
	# base class initialization
	$self->_basic_init(%p);

	# split pathname into path, basename, extension
	if ($p{filename} =~ /^(.*)\%d\{([^\}]*)\}(.*)$/) {
		$self->{rolling_filename_prefix}  = $1;
		$self->{rolling_filename_postfix} = $3;
		$self->{rolling_filename_format}  = Log::Log4perl::DateFormat->new($2);
		$p{filename} = $self->_createFilename();
	} elsif ($p{filename} =~ /^(.*)(\.[^\.]+)$/) {
		$self->{rolling_filename_prefix}  = $1;
		$self->{rolling_filename_postfix} = $2;
		$self->{rolling_filename_format}  = Log::Log4perl::DateFormat->new('-yyyy-MM-dd');
		$p{filename} = $self->_createFilename();
	} else {
		$self->{rolling_filename_prefix}  = $p{filename};
		$self->{rolling_filename_postfix} = '';
		$self->{rolling_filename_format}  = Log::Log4perl::DateFormat->new('.yyyy-MM-dd');
		$p{filename} = $self->_createFilename();
	}

	$self->_make_handle(%p);
			
	return $self;
}

sub log_message { # parts borrowed from Log::Dispatch::FileRotate, Thanks!
	my $self = shift;
	my %p = @_;

	my $filename = $self->_createFilename();
	if ($filename ne $self->{filename}) {
		$self->{filename} = $filename;
		$self->{rolling_fh_pid} = 'x'; # force reopen
	}

	if ( $self->{close} ) {
		$self->_open_file;
		$self->_lock();
		my $fh = $self->{fh};
		print $fh $p{message};
		$self->_unlock();
		close($fh);
		$self->{fh} = undef;
	} elsif (defined $self->{fh} and $self->{rolling_fh_pid}||'' eq $$) { # flock won't work after a fork()
		my $inode  = (stat($self->{fh}))[1];         # get real inode
		my $finode = (stat($self->{filename}))[1];   # Stat the name for comparision
		if(!defined($finode) || $inode != $finode) { # Oops someone moved things on us. So just reopen our log
			$self->_open_file;
		}
		$self->_lock();
		my $fh = $self->{fh};
		print $fh $p{message};
		$self->_unlock();
	} else {
		$self->{rolling_fh_pid} = $$;
		$self->_open_file;
		$self->_lock();
		my $fh = $self->{fh};
		print $fh $p{message};
		$self->_unlock();
	}
}

sub _lock { # borrowed from Log::Dispatch::FileRotate, Thanks!
	my $self = shift;
	flock($self->{fh},LOCK_EX);
	# Make sure we are at the EOF
	seek($self->{fh}, 0, 2);
	return 1;
}

sub _unlock { # borrowed from Log::Dispatch::FileRotate, Thanks!
	my $self = shift;
	flock($self->{fh},LOCK_UN);
	return 1;
}

sub _current_time { # borrowed from Log::Log4perl::Layout::PatternLayout, Thanks!
	# Return secs and optionally msecs if we have Time::HiRes
	if($TIME_HIRES_AVAILABLE) {
		return (Time::HiRes::gettimeofday());
	} else {
		return (time(), 0);
	}
}

sub _createFilename {
	my $self = shift;
	return $self->{rolling_filename_prefix}
	     . $self->_format()
	     . $self->{rolling_filename_postfix};
}

sub _format {
	my $self = shift;
	my $result = $self->{rolling_filename_format}->format($self->_current_time());
	$result =~ s/\$\$/$$/g;
	return $result;
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Log::Dispatch::File::Rolling - Object for logging to date/time/pid stamped 
files

=head1 SYNOPSIS

  use Log::Dispatch::File::Rolling;

  my $file = Log::Dispatch::File::Rolling->new(
                             name      => 'file1',
                             min_level => 'info',
                             filename  => 'Somefile%d{yyyyMMdd}.log',
                             mode      => 'append' );

  $file->log( level => 'emerg', message => "I've fallen and I can't get up\n" );

=head1 ABSTRACT

This module provides an object for logging to files under the
Log::Dispatch::* system.

=head1 DESCRIPTION

This module subclasses Log::Dispatch::File for logging to date/time 
stamped files. See L<Log::Dispatch::File> for instructions on usage. 
This module differs only on the following three points:

=over 4

=item fork()-safe

This module will close and re-open the logfile after a fork.

=item multitasking-safe

This module uses flock() to lock the file while writing to it.

=item stamped filenames

This module supports a special tag in the filename that will expand to the current date/time/pid.

It is the same tag Log::Log4perl::Layout::PatternLayout uses, see 
L<Log::Log4perl::Layout::PatternLayout>, chapter "Fine-tune the date". 
In short: Include a "%d{...}" in the filename where "..." is a format 
string according to the SimpleDateFormat in the Java World 
(http://java.sun.com/j2se/1.3/docs/api/java/text/SimpleDateFormat.html). 
See also L<Log::Log4perl::DateFormat> for information about further 
restrictions.

In addition to the format provided by Log::Log4perl::DateFormat this 
module also supports '$$' for inserting the PID. This should not be 
needed regularly as this module also supports logfile sharing between 
processes, but if you've got a high load on your logfile or a system 
that doesn't support flock()...

=head1 HISTORY

=over 8

=item 0.99

Original version; created by h2xs 1.22 with options

	-A
	-C
	-X
	-b5.6.1
	-nLog::Dispatch::File::Rolling
	--skip-exporter
	-v0.99

=item 1.00

Initial coding

=item 1.01

Someone once said "Never feed them after midnight!"---Ok, let's append: "Never submit any code after midnight..."

Now it is working, I also included 4 tests.

=back

=head1 SEE ALSO

L<Log::Dispatch::File>, L<Log::Log4perl::Layout::PatternLayout>, http://java.sun.com/j2se/1.3/docs/api/java/text/SimpleDateFormat.html, L<Log::Log4perl::DateFormat>, 'perldoc -f flock', 'perldoc -f fork'.

=head1 AUTHOR

M. Jacob, E<lt>jacob@j-e-b.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2003 M. Jacob E<lt>jacob@j-e-b.netE<gt>

Based on:

  Log::Dispatch::File::Stamped by Eric Cholet <cholet@logilune.com>
  Log::Dispatch::FileRotate by Mark Pfeiffer, <markpf@mlp-consulting.com.au>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut