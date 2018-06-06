package Fadi::Migration::MySQL;
use strict;
use warnings;
use DBI;
use FindBin;
use Term::ANSIColor qw(:constants);
use YAML;
use feature qw{ say };

my $configPath = "$FindBin::RealBin/migration.yml";

my $mysqlTypes = {
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
			min => -9223372036854775808,
			max =>  9223372036854775807,
		},
		unsigned => {
			min => 0,
			max => 18446744073709551615,
		},
	},
	char => {
		
	},


};

sub getEnvName
{
	my($self) = @_;
	my $path = sprintf(
		"%s/%s/ENV_NAME",
		$FindBin::RealBin,
		$self->config->{"dir"}{"env_name"}
	);
	my $fh = IO::File->new("< $path") or die "cannot read ENV_NAME $path";
	my $fbody = "";
	while(read $fh, my $buf, 100)
	{
		$fbody .= $buf;
	}
	$fh->close;
	chomp $fbody;
	$fbody
}

sub dbh
{
	my($self, $name) = @_;
	$name ||= $self->{"currentName"};
	$self->{"dbhs"}{$name}
}

sub dbhNames
{
	my($self) = @_;
	\(keys %{$self->{"dbhs"}})
}

sub config
{
	$_[0]{"configBody"}
}

sub new
{
	my($self, %args) = @_;
	bless \%args, $self
}

sub usage
{
	my($self, $message) = @_;
	say RED, qq|\n  error: "$message"|, CLEAR if $message;
	say CYAN;
	say <<"_USAGE_";
  usage: The following are the available command line interface commands

    to oldest
      \$ $0 migrate 0

    to newest
      \$ $0 migrate 99991231235959

    create a new migration file
      \$ $0 migration [schema-name] [table-name]  

    create all migration files
      \$ $0 migration [schema-name]

    insert random 10000 records
      \$ $0 seed 10000 [schema-name] [table-name] 

_USAGE_
	say CLEAR;
	exit
}

sub loadConfig
{
	my($self, $path) = @_;
	return $self->usage("config " . $path . " is not found.") unless -f $path;
	YAML::LoadFile($path)
}

sub connect
{
	my($self, $name) = @_;
	my $envName = $self->getEnvName;
	die "ENV_NAME is not found." if not $envName;
	die "illegal env" if not exists $self->config->{"auth"}{$envName};
	die "illegal schema" if not exists $self->config->{"auth"}{$envName}{$name};
	$self->{"dbhs"} ||= {};
	$self->{"startedTransactions"} ||= {};
	$self->{"currentName"} = $name;
	if(exists $self->{"dbhs"}{$name} and $self->{"dbhs"}{$name}->ping)
	{
		return $self->{"dbhs"}{$name};
	}

	# new connections begin
	my $auth = $self->config->{"auth"}{$envName}{$name};
	my $schemaName = exists $auth->{"schema"} ? $auth->{"schema"} : $name;
	my @dsn = (
		'dbi:mysql:' . $schemaName . ':host=' . $auth->{'hostname'},
		$auth->{'username'},
		$auth->{'password'},
	);
	my $dbh = DBI->connect(
		@dsn,
		{
			AutoCommit => 0,
			PrintError => 1,
			RaiseError => 1,
		}
	) or die "cannot connect the database.";
   	if(not $self->{"startedTransactions"}{$name})
	{
		$self->{"startedTransactions"}{$name} = 1;
	}
	$self->{"dbhs"}{$name} = $dbh
}

sub rollback
{
	my($self) = @_;
	my $rollbacked = 0;
	return 1 if not $self->{"dbhs"};
	for my $name(keys %{$self->{"dbhs"}})
	{
		my $dbh = delete $self->{"dbhs"}{$name};
		$dbh->rollback;
		$dbh->disconnect;
		delete $self->{"startedTransactions"}{$name};
		$rollbacked++;
	}
	$rollbacked
}

sub commit
{
	my($self) = @_;
	my $committed = 0;
	for my $name(keys %{$self->{"dbhs"}})
	{
		my $dbh = delete $self->{"dbhs"}{$name};
		$dbh->commit;
		$dbh->disconnect;
		delete $self->{"startedTransactions"}{$name};
		$committed++;
	}
	$committed
}

sub reconnect
{
	my($self, $name) = @_;
	$name ||= $self->{"currentName"};
	$self->{"dbhs"}{$name} or $self->connect($name);
	$self->{"dbhs"}{$name}->ping or do {
		$self->{"dbhs"}{$name}->disconnect;
		$self->{"dbhs"}{$name}->connect($name);
	}
}

sub DESTROY
{
	my($self) = @_;
	return 1 if not $self->{"dbhs"};
	for my $dbh(values %{$self->{"dbhs"}})
	{
		$dbh->disconnect;
	}
	1
}

sub query
{
	my($self, $sql, $binds, $schemaName) = @_;
	$self->reconnect($schemaName) or return;
	my $sth = $self->dbh($schemaName)->prepare($sql);
	my $res = ref $binds ? $sth->execute(@$binds) : $sth->execute;
	($res, $sth)
}

sub selectQuery
{
	my($self, $sql, $binds) = @_;
	my($res, $sth) = $self->query($sql, $binds);
	return if not $res;

	my @rows;
	if($res > 0)
	{
		while(my $row = $sth->fetchrow_hashref)
		{
			push @rows, $row;
		}
	}
	$sth->finish;
	\@rows
}

sub tableColumns
{
	my($self, $schemaName, $tableName) = @_;
	$self->selectQuery(
		qq|SELECT * FROM information_schema.COLUMNS | .
		qq|WHERE TABLE_SCHEMA='$schemaName' | .
		qq|AND TABLE_NAME = '$tableName'|
	)
}

sub insert
{
	my($self, $schemaName, $tableName, $insertSet) = @_;
	my @columns;
	my @binds;
	while(my($columnName, $columnValue) = each %$insertSet)
	{
		push @columns, qq|`$columnName` = ?|;
		push @binds, $columnValue;
	}
	my $sql = "INSERT INTO `$tableName` SET " . join(", ", @columns);
	my($res, $sth) = eval { $self->query($sql, \@binds, $schemaName) };
	eval { $sth->finish };
	$res
}

1

