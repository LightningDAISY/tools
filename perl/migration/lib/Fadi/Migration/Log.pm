package Fadi::Migration::Log;
use strict;
use warnings;
use IO::File;
use feature qw{ say };

my @weekdays = qw{ Sun Mon Tue Wed Thu Fri Sat };

sub _now
{
	my($sec,$min,$hour,$day,$month,$year,$wday) = localtime;
	sprintf(
		"%d-%02d-%02d[%s] %02d:%02d:%02d",
		$year+1900, $month+1, $day, $weekdays[$wday],
		$hour, $min, $sec
	)
}

sub write
{
	my($self, $message) = @_;
	my $fh = IO::File->new(qq|>> $self->{"path"}|) or die qq|cannot write $self->{"path"}|;
	say $fh $self->_now, " ", $message;
	$fh->close
}

sub new
{
	my($class, %args) = @_;
	bless \%args, $class
}

1

__END__


Fadi::Migration::Log->new(
	path => "/var/log/migration.log",
)->write(
	"Error!!1"
);
