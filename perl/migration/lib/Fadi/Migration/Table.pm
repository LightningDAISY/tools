package Fadi::Migration::Table;
use strict;
use warnings;
use Term::ANSIColor qw(:constants);
use parent qw{ Fadi::Migration::MySQL };
use feature qw{ say };

sub _initArgs
{
	my($self) = @_;
	$self->{"fields"} = [];
	$self->{"dropFields"} = [];
	$self->{"changeFields"} = [];
	$self->{"keys"} = [];
	$self->{"primary_keys"} = [];
	$self->{"unique_keys"} = {};
	$self->{"keys"} = {};
	$self->{"drop_keys"} = [];
	$self->{"rename_to"} = undef;
	$self->{"dbhs"} ||= {};
	$self
}

sub new
{
	my($class,%args) = @_;
	my $ins = bless \%args, $class;
	$ins->_initArgs;
}

sub addField
{
	my($self, $hashref) = @_;
	for my $key(keys %$hashref)
	{
		push @{$self->{"fields"}}, +{ $key => $hashref->{$key} };
	}
	1
}

sub changeField
{
	my($self, $hashref) = @_;
	for my $key(keys %$hashref)
	{
		push @{$self->{"changeFields"}}, +{ $key => $hashref->{$key} };
	}
	1
}

sub dropField
{
	my($self, $hashref) = @_;
	for my $key(keys %$hashref)
	{
		push @{$self->{"dropFields"}}, +{ $key => $hashref->{$key} };
	}
	1
}

#
# primary_keys = ["column1", "column2"],
#
# unique_keys = {
#   uk1 => ["column3", "column4"]
# },
#
# keys => {
#   k1 => ["column4"],
# },
#
# ex. $ins->addKey({
#   byBirthday => {
#     COLUMN => ["birthday"],
#     UNIQUE => 0,
# });
#
sub addKey
{
	my($self, $hashref) = @_;
	for my $key(keys %$hashref)
	{
		my $value = $hashref->{$key};
		die "IS NOT HASHREF $key" if not ref $value;
		die "INVALID FORMAT $key" if not exists $value->{"COLUMNS"};
		my $isPrimary = $key eq "PRIMARY" ? 1 : 0;
		my $isUnique  = exists $value->{"UNIQUE"} ? $value->{"UNIQUE"} ? 1 : 0 : 0;
		if($isPrimary)
		{
			push @{$self->{"primary_keys"}}, @{$value->{"COLUMNS"}}
		}
		elsif($isUnique)
		{
			$self->{"unique_keys"}{$key} = $value->{"COLUMNS"}
		}
		else
		{
			$self->{"keys"}{$key} = $value->{"COLUMNS"}
		}
	}
	1
}

#
# ex. $ins->dropKey({
#   byBirthday => 1
# });
#
sub dropKey
{
	my($self, $hashref) = @_;
	for my $key(keys %$hashref)
	{
		push @{$self->{"drop_keys"}}, $key
	}
	1
}

#
# ex. $ins->renameTo("new_table_name");
#
sub renameTo
{
	my($self, $newTableName) = @_;
	$self->{"rename_to"} = $newTableName
}

sub _backQuote
{
	my($self, $name) = @_;
	if("ARRAY" eq ref $name)
	{
		my @tmp;
		for my $column(@$name)
		{
			push @tmp, "`" . $column . "`"
		}
		\@tmp
	}
	else
	{
		"`" . $name . "`"
	}
}

sub _singleQuote
{
	my($self, $value) = @_;
	q|'| . $value . q|'|
}

sub _expandFields
{
	my($self) = @_;
	my @rows;
	for my $field(@{$self->{"fields"}})
	{
		for my $columnName(keys %$field)
		{
			my $column = $field->{$columnName};
			my @sqls = ($self->_backQuote($columnName));
			push @sqls, $column->{"TYPE"} if exists $column->{"TYPE"};
			push @sqls, "NOT NULL" if not exists $column->{"NULL"} or not $column->{"NULL"};
			push @sqls, "DEFAULT " . $self->_singleQuote($column->{"DEFAULT"}) if exists $column->{"DEFAULT"};
			push @sqls, "COMMENT " . $self->_singleQuote($column->{"COMMENT"}) if exists $column->{"COMMENT"};
			push @rows, join " ", @sqls;
		}
	}
	push @rows, "PRIMARY KEY (" . join(",", @{$self->_backQuote($self->{"primary_keys"})}) . ")"
		if scalar @{$self->{"primary_keys"}};

	for my $indexName(keys %{$self->{"unique_keys"}})
	{
		push(
	   		@rows,
			"UNIQUE KEY " . $self->_backQuote($indexName) . " (" .
			join(
				",",
				@{$self->_backQuote($self->{"unique_keys"}{$indexName})}
			) . ")"
		)
	}
	for my $indexName(keys %{$self->{"keys"}})
	{
		push(
	   		@rows,
			"KEY " . $self->_backQuote($indexName) . " (" .
			join(
				",",
				@{$self->_backQuote($self->{"keys"}{$indexName})}
			) . ")"
		)
	}
	" (\n" . join(",\n", @rows) . "\n)\n"
}

sub _runSql
{
	my($self, $schemaName, $sql, $binds) = @_;
	say GREEN . "SQL " . CLEAR . $sql;
	$binds ||= [];
	my $res = 1;
	if(not $self->{"dryrun"})
	{
		my($res, $sth) = $self->query($sql, $binds, $schemaName);
		$sth->finish;
	}
	$res
}

#
# caller: alterTable
# 
# $self->{"fields"}の要素を1件受け取りADD COLUMNに変換
#
# {
#   "cateMday" => {
#     "NULL"    => 1,
#     "DEFAULT" => "2000-01-01 00:00:00",
#     "TYPE"    => "datetime",
#   },
# },
#
sub _fieldsSql
{
	my($self, $field) = @_;
	my @sql = ("ADD COLUMN");
	my($name, $values) = %$field;
	push @sql, $name;
	push @sql, $values->{"TYPE"};
	push @sql, "NOT NULL" if(not exists $values->{"NULL"} or not $values->{"NULL"});
	push @sql, "DEFAULT " . $self->_singleQuote($values->{"DEFAULT"}) if $values->{"DEFAULT"};
	push @sql, "COMMENT " . $self->_singleQuote($values->{"COMMENT"}) if $values->{"COMMENT"};
	push @sql, "AFTER " . $self->_backQuote($values->{"AFTER"}) if $values->{"AFTER"};
	join " ", @sql
}

#
# caller: alterTable
# 
# $self->{"changeFields"}の要素を1件受け取りCHANGE COLUMNに変換
#
# {
#   "cateMday" => {
#     "NAME"    => "cateMday"
#     "NULL"    => 1,
#     "DEFAULT" => "2000-01-01 00:00:00",
#     "TYPE"    => "datetime",
#   },
# },
#
sub _changeFieldsSql
{
	my($self, $field) = @_;
	my @sql = ("CHANGE COLUMN");
	my($name, $values) = %$field;
	my $newName = $values->{"NAME"} || $name;

	push @sql, $name, $newName, $values->{"TYPE"};
	push @sql, "NOT NULL" if(not exists $values->{"NULL"} or not $values->{"NULL"});
	push @sql, "DEFAULT " . $self->_singleQuote($values->{"DEFAULT"}) if $values->{"DEFAULT"};
	push @sql, "COMMENT " . $self->_singleQuote($values->{"COMMENT"}) if $values->{"COMMENT"};
	join " ", @sql
}

#
# caller: alterTable
#
sub _dropFieldsSql
{
	my($self, $field) = @_;
	my @sql = ("DROP COLUMN");
	my($name, $values) = %$field;
	push @sql, $name;
	join " ", @sql
}

sub _addKeysSql
{
	my($self, $field) = @_;
	my @sql = ("ADD INDEX");
	my($name, $values) = %$field;
	push @sql, $name, "(", join(", ", @{$self->_backQuote($values->{"COLUMNS"})}), ")";
	join " ", @sql
}

sub createTable
{
	my($self, $schemaName, $tableName, $tableComment) = @_;
	my $sql = "CREATE TABLE IF NOT EXISTS "
			. $self->_backQuote($schemaName) . "."
			. $self->_backQuote($tableName)
			. $self->_expandFields
			. "ENGINE=InnoDB DEFAULT CHARSET=utf8"
	;
	$sql .= qq| COMMENT="$tableComment"| if $tableComment;
	$sql .= qq|\n|;
	$self->_runSql($schemaName, $sql);
	$self->_initArgs
}

sub alterTable
{
	my($self, $schemaName, $tableName) = @_;
	my $baseSql = "ALTER TABLE "
				. $self->_backQuote($schemaName) . "."
				. $self->_backQuote($tableName) . " "
	;

	for my $key(qw{ dropFields changeFields fields })
	{
		for my $field(@{$self->{$key}})
		{
			my $method = "_" . $key . "Sql";
			my $sql = $baseSql . $self->$method($field);
			$self->_runSql($schemaName, $sql);
		}
	}

	# primary keys
	if(scalar @{$self->{"primary_keys"}})
	{
		my $sql = $baseSql . "ADD INDEX PRIMARY (" .
			join(", ", @{$self->_backQuote($self->{"primary_keys"})}) .
			")";
		$self->_runSql($schemaName, $sql);
	}

	# unique keys
	if(scalar keys %{$self->{"unique_keys"}})
	{
		for my $keyName(keys %{$self->{"unique_keys"}})
		{
			my $sql = $baseSql . "ADD INDEX UNIQUE `$keyName` (" .
				join(", ", @{$self->_backQuote($self->{"unique_keys"}{$keyName})}) .
				")";
			$self->_runSql($schemaName, $sql);
		}
	}

	# select keys
	if(scalar keys %{$self->{"keys"}})
	{
		for my $keyName(keys %{$self->{"keys"}})
		{
			my $sql = $baseSql . "ADD INDEX `$keyName` (" .
				join(", ", @{$self->_backQuote($self->{"keys"}{$keyName})}) .
				")";
			$self->_runSql($schemaName, $sql);
		}
	}

	# drop_index
	if(scalar @{$self->{"drop_keys"}})
	{
		for my $keyName(@{$self->{"drop_keys"}})
		{
			my $sql = $baseSql . "DROP INDEX `$keyName`";
			$self->_runSql($schemaName, $sql);
		}
	}

	# rename table
	if($self->{"rename_to"})
	{
		my $sql = $baseSql
				. "RENAME TO "
				. $self->_backQuote($self->{"rename_to"})
		;
		$self->_runSql($schemaName, $sql);
	}
	$self->_initArgs
}

sub dropTable
{
	my($self, $schemaName, $tableName) = @_;
	my $sql = "DROP TABLE IF EXISTS " . $tableName;
	$self->_runSql($schemaName, $sql);
	$self->_initArgs
}

1

__END__

