package Fadi::Migration::Seeder;
use strict;
use warnings;
#use Math::BigInt qw(:constant);
use Math::BigInt;
use Fadi::Migration::Seeder::Kanji;
use Term::ANSIColor qw(:constants);
use parent qw{ Fadi::Migration::MySQL };
use feature qw{ say };

# duplicate entry retry limit
my $duplicateLimit = 20;

my %mysqlTypes = (
	tinyint => {
		type => "number",
		signed => {
			min => -128,
			max => 127,
		},
		unsigned => {
			min => 0,
			max => 255,
		},
	},
	smallint => {
		type => "number",
		signed => {
			min => -32768,
			max => 32767,
		},
		unsigned => {
			min => 0,
			max => 65535,
		},
	},
	mediumint => {
		type => "number",
		signed => {
			min => -8388608,
			max =>  8388607,
		},
		unsigned => {
			min => 0,
			max => 16777215,
		},
	},
	int => {
		type => "number",
		signed => {
			min => -2147483648,
			max =>  2147483647,
		},
		unsigned => {
			min => 0,
			max => 4294967295,
		},
	},
	bigint => {
		type => "number",
		signed => {
			min => "-9223372036854775808",
			max =>  "9223372036854775807",
		},
		unsigned => {
			min => 0,
			max => "18446744073709551615",
		},
	},
	char => {
		type => "string",
		max => 255,
	},
	varchar => {
		type => "string",
		max => 255,
	},
	tinyblob => {
		type => "string",
		max => 255,
	},
	blog => {
		type => "string",
		max => 65535,
	},
	mediumblob => {
		type => "string",
		max => 16777215,
	},
	longblog => {
		type => "string",
		max => 4294967295,
	},

	tinytext => {
		type => "string",
		max => 255,
	},
	text => {
		type => "string",
		max => 65535,
	},
	mediumtext => {
		type => "string",
		max => 16777215,
	},
	longtext => {
		type => "string",
		max => 4294967295,
	},
);

my $kanji = Fadi::Migration::Seeder::Kanji->new;

sub new
{
	my($class, %args) = @_;
	bless \%args, $class
}

sub _assembleDigits
{
	my($self, $array) = @_;
	my $retval;
	if(scalar(@$array) > 1)
	{
		foreach (@$array)
		{
			$retval .= sprintf "%04x", $_
		}
	}
	else
	{ 
		return sprintf "%x", $array->[0];
	}
	$retval
}

sub _getRandomHexDigits
{
	my($self, $max, $count) = @_;
	return '' if $count < 1;
	my @digits;
	for(1 .. $count) { push @digits, int rand($max) }
	return $self->_assembleDigits(\@digits);
}

sub _randomBigint
{
	my($self, $max) = @_;
	my $asHex = $max->as_hex;
	my $len    = length $asHex;
	my $bottomQuads = int(($len - 3) / 4);
	my $topQuadChunk = substr($asHex, 0, $len - 4 * $bottomQuads);
	my $num = '0x';
	$num .= $self->_getRandomHexDigits(hex $topQuadChunk, 1);
	$num .= $self->_getRandomHexDigits(65535, $bottomQuads);
	Math::BigInt->new($num)
}

sub _minMaxTypeDate
{
	my($self, $type) = @_;
	if($type eq "date" or $type eq "datetime" or $type eq "time")
	{
		(
			type => $type,
			min  => undef,
			max  => undef,
		)
	}
	else
	{
		die "unknown type : " . $type
	}
}

sub _minMaxType
{
	my($self, $columnType) = @_;
	$columnType =~ /([a-z]+)(?:\((.+?)\))?\s*([a-z]*)/;
	my $type = $1;
	my $size = $2;
	my $signed = $3 ? $3 eq "unsigned" ? "unsigned" : "signed": "signed";

	my %result = (
		max  => 0,
		min  => 0,
		type => undef,
	);
	if(exists $mysqlTypes{$type})
	{
		if(exists $mysqlTypes{$type}{$signed})
		{
			%result = (
				max  => $mysqlTypes{$type}{$signed}{"max"},
				min  => $mysqlTypes{$type}{$signed}{"min"},
				type => $mysqlTypes{$type}{"type"},
			);
		}
		else
		{
			%result = (
				max  => $mysqlTypes{$type}{"max"},
				min  => 0,
				type => $mysqlTypes{$type}{"type"},
			);
			
		}
	}
	elsif($type eq "date" or $type eq "time" or $type eq "datetime")
	{
		%result = (
			type => $type,
		);
	}
	elsif($columnType =~ /enum(\(.+\))/)
	{
		my @arr = eval $1;
		%result = (
			type => "enum",
			max  => \@arr,
		);
	}

   	# REAL等のエイリアスはMySQLで吸収されます。
	elsif($columnType =~ /decimal\((\d+),(\d+)\)/)
	#elsif($type =~ /decimal/)
	{
		%result = (
			type => "decimal",
			max => $1,
			int => $1 - $2,
			few => $2,
			min => 0,
		)
	}
	elsif($type eq "float")
	{
		%result = (
			type => "decimal",
			max => 6,
			int => 2,
			few => 4,
			min => 0,
		)
	}
	elsif($type eq "double")
	{
		%result = (
			type => "decimal",
			max => 12,
			int => 4,
			few => 8,
			min => 0,
		)
	}
	($result{"type"}, $result{"min"}, $result{"max"}, $result{"int"}, $result{"few"})
}

sub randomValueString
{
	my($self,$max) = @_;
	my $string = "";
	for(my $i=0; $i< $max;)
	{
		my $j = chr(int(rand 127));
		if(($j =~ /[a-zA-Z0-9]/))
		{
			$string .= $j;
			$i++;
		}
	}
	$string
}

sub randomValueNumber
{
	my($self, $max, $min) = @_;
	$max or die "set a max number";
	$min ||= 0;
	$max = Math::BigInt->new($max);
	$min = Math::BigInt->new($min);
	$max - $min or die "narrow of range";
	my $tries = 1000;
	for(my $i=0 ; $i<$tries; $i++)
	{
		my $randNum = $self->_randomBigint($max);
		$randNum += $min;
		next if $randNum > $max;
		return $randNum->numify;
	}
	$min
}

sub randomValueTime
{
	my($self) = @_;
	my $time = time - int(rand 2592000);
	my($sec,$min,$hour) = localtime $time;
	sprintf "%02d:%02d:%02d", $hour, $min, $sec;
}

sub randomValueDate
{
	my($self) = @_;
	my $time = time - int(rand 2592000);
	my($sec,$min,$hour,$day,$mon,$year) = localtime $time;
	sprintf "%d/%02d/%02d", $year+1900, $mon+1, $day;
}

sub randomValueDatetime
{
	my($self) = @_;
	$self->randomValueDate . " " . $self->randomValueTime
}

sub randomValueDecimal
{
	my($self, $int, $few) = @_;
	my $intMax = int("1" . ("0" x $int)) - 1;
	my $fewMax = int("1" . ("0" x $few)) - 1;

	if($few and int($few) > 0)
	{
		$self->randomValueNumber($intMax, 0) . "." . $self->randomValueNumber($fewMax, 0)
	}
	else
	{
		$self->randomValueNumber($intMax, 0)
	}
}

sub randomValueEnum
{
	my($self, $values) = @_;
	my $i = int rand scalar @$values;
	$values->[$i]
}

sub randomValue
{
	my($self, $columnType) = @_;
	my($type, $min, $max, $int, $few) = $self->_minMaxType($columnType);
	if(not $type)
	{
		die "cannot read type $columnType (", $type, ", ", $max, ", ", $max, ")"
	}
	elsif("string" eq $type)
	{
		return $kanji->randomString($max,$min)
	}
	elsif("number" eq $type)
	{
		return $self->randomValueNumber($max)
	}
	elsif("date" eq $type)
	{
		return $self->randomValueDate()
	}
	elsif("time" eq $type)
	{
		return $self->randomValueTime()
	}
	elsif("datetime" eq $type)
	{
		return $self->randomValueDatetime()
	}
	elsif("decimal" eq $type)
	{
		return $self->randomValueDecimal($int, $few)
	}
	elsif("enum" eq $type)
	{
		return $self->randomValueEnum($max)
	}
	else
	{
		die "unknown type $type ($columnType)"
	}
}

sub run
{
	my($self, $insertTimes, $schemaName, @tableNames) = @_;
	$self->usage("invalid parameters.") if(not $insertTimes or not $schemaName or not $tableNames[0]);

	my $commitThreshold = 100;
	$self->connect($schemaName) or return $self->usage(
		"cannot connect the database $schemaName"
	);
	for my $tableName(@tableNames)
	{
		my %insertSet;
		my $columns = $self->tableColumns($schemaName, $tableName);
		if(not scalar @$columns)
		{
			say RED, "table $tableName is not found.", CLEAR;
			next;
		}
		my $commitCounter = 0;
		my $errorCounter  = 0;
		while($commitCounter < $insertTimes)
		{
			for my $column(@$columns)
			{
				next if $column->{"EXTRA"} eq "auto_increment";
				$insertSet{$column->{"COLUMN_NAME"}} = $self->randomValue(
					$column->{"COLUMN_TYPE"} 
				);
			}
			my $res = $self->insert($schemaName, $tableName, \%insertSet);
			if(not $res)
			{
				$errorCounter++;
				if($errorCounter >= $duplicateLimit)
				{
					$self->rollback;
					say RED, "too many errors & rollbacked", CLEAR;
					return;
				}
				next;
			}
			$commitCounter++;
			if($commitCounter >= $commitThreshold)
			{
				say "commit $commitCounter records";
				$self->commit;
				$commitCounter = 0;
			}
		}
		if($commitCounter > 0)
		{
			$self->commit;
			say "commit $commitCounter records";
		}
		say GREEN, "inserted $insertTimes records to $tableName\.", CLEAR;
	}
}

1

