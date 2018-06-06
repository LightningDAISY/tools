package Fadi::Migration;
use strict;
use warnings;
use DBI;
use IO::File;
use Fadi::Migration::Log;
use Fadi::Migration::Seeder;
use Term::ANSIColor qw(:constants);
our $VERSION = 1.0.0;
use feature qw{ say };
use parent qw{ Fadi::Migration::MySQL };

my %modes = (
	"migration" => 1,
	"migrate"   => 1,
	"seed"      => 1,
);
my $timeStamp;

my %informationColumns = (
	# information_schama => migration_attribute
	COLUMN_NAME       => "NAME",
	COLUMN_DEFAULT    => "DEFAULT",
	IS_NULLABLE       => "NULL",
	COLUMN_TYPE       => "TYPE",
	NUMERIC_PRECISION => "CONSTRAINT",
	COLUMN_COMMENT    => "COMMENT",
	EXTRA             => "AUTO_INCREMENT",
	CHARACTER_MAXIMUM_LENGTH => "CONSTRAINT",
);

sub timeStamp { $_[0]{"timeStamp"} }

sub getTargetVersion
{
	my($sec,$min,$hour,$day,$month,$year) = localtime;
	sprintf "%d%02d%02d%02d%02d%02d", $year+1900, $month+1, $day, $hour, $min, $sec;
}

sub currentVersionPath
{
	my($self) = @_;
	my $dir = $self->{"baseDir"} . "/" . $self->config->{"dir"}{"current"};
	mkdir $dir, 0755 unless -d $dir;
	my $path = $dir . "/" . $self->config->{"file"}{"version"};
	unless(-f $path)
	{
		my $fh = IO::File->new("> $path") or die "cannot write current-version $path";
		print $fh "0";
		$fh->close
	}
	$path
}

sub getCurrentVersion
{
	my($self) = @_;
	my $path = $self->currentVersionPath;
	my $fh = IO::File->new("< $path") or die "cannot read current-version $path";
	my $fbody = "";
	while(read $fh, my $buf, 100)
	{
		$fbody .= $buf;
	}
	$fh->close;
	chomp $fbody;
	$fbody
}

sub setCurrentVersion
{
	my($self, $version) = @_;
	my $path = $self->currentVersionPath;
	$version ||= "0";
	if(not $self->{"dryrun"})
	{
		my $fh = IO::File->new("> $path") or die "cannot write current-version $path";
		print $fh $version;
		$fh->close;
	}
	$path
}

sub tableKeys
{
	my($self, $schemaName, $tableName) = @_;
	$self->selectQuery(
		qq|SELECT * FROM information_schema.STATISTICS | .
		qq|WHERE TABLE_SCHEMA='$schemaName' | .
		qq|AND TABLE_NAME = '$tableName'|
	)
}

sub tableComment
{
	my($self, $schemaName, $tableName) = @_;
	my $rows = $self->selectQuery(
		qq|SELECT * FROM information_schema.TABLES | .
		qq|WHERE TABLE_SCHEMA='$schemaName' | .
		qq|AND TABLE_NAME = '$tableName'|
	);
	$rows->[0]{"TABLE_COMMENT"}
}

sub migrationTemplate
{
	my($self, $schemaName, $tableName, $tableComment) = @_;
	$tableComment ||= "";
    qq|package Migration_$tableName\_$timeStamp;\n| .
	qq|use parent "Fadi::Migration::Table";\n\n| .
	qq|sub up\n| .
	qq|{\n| .
	qq|\tmy(\$self) = \@_;\n| .
	qq|%s\n| .
	qq|%s\n| .
	qq|\t\$self->createTable("$schemaName", "$tableName", "$tableComment");\n| .
	qq|}\n\n| .
	qq|sub down\n| .
	qq|{\n| .
	qq|\tmy(\$self) = \@_;\n| .
	qq|\t\$self->dropTable("$schemaName", "$tableName");\n| .
	qq|}\n\n| .
	qq|1\n|
}

sub templateFieldParts
{
	my($self,$fields) = @_;
	my $body = "";
	my $part = "";

    for my $field(@$fields)
	{
		$part = "";
		for my $key(sort keys %$field)
		{
			my $value = $field->{$key};
			if($key eq $informationColumns{"COLUMN_NAME"})
			{
				$part = qq|\t\$self->addField(\{\n\t\t"$value" => \{\n| . $part;
			}
			#elsif($key eq $informationColumns{"DATA_TYPE"})
			#{
			#	$part .= qq|\t\t\t"$key" => "$value",\n|;
			#}
			elsif($value)
			{
				$part .= qq|\t\t\t"$key" => "$value",\n|;
			}
			#else
			#{
			#	$part .= qq|\t\t\t"$key" => undef,\n|;
			#}
		}
		$part .= qq|\t\t}\n\t});\n|;
		$body .= $part;
	}
    $body
}

sub templateKeyParts
{
	my($self,$keys) = @_;
	my %struct;
	for my $key(@$keys)
	{
		my $idxName = $key->{"INDEX_NAME"};
		if(not exists $struct{$idxName})
		{
			$struct{$idxName} = +{
				COLUMNS => [],
				UNIQUE  => 1,
			};
		}
		push @{$struct{$idxName}{"COLUMNS"}}, $key->{"COLUMN_NAME"};
		$struct{$idxName}{"UNIQUE"} = 0 if $key->{"NON_UNIQUE"};
	}
	my $body = "";
	for my $key(keys %struct)
	{
		my $value = $struct{$key};
		$body .= qq|\t\$self->addKey({\n|
			   . qq|\t\t"$key" => {\n|
			   . qq|\t\t\t"COLUMNS" => ["| . join(q|", "|, @{$value->{"COLUMNS"}}) . qq|"],\n|
			   . qq|\t\t\t"UNIQUE"  => | . $value->{"UNIQUE"} . qq|,\n|
			   . qq|\t\t}\n|
			   . qq|\t});\n|;
		;
	}
	$body
}

sub columns2struct
{
	my($self, $schemaName, $tableName, $columns) = @_;
	my @fields;
	my $migrationKey;
	for my $column(@$columns)
	{
		my %field;
		for my $infoKey(keys %informationColumns)
		{
			$migrationKey = $informationColumns{$infoKey};
			if(not exists $column->{$infoKey})
			{
				next;
			}
			elsif($infoKey eq "IS_NULLABLE")
			{
				$field{$migrationKey} = $column->{"IS_NULLABLE"} eq "YES" ? 1 : 0;
			}
			elsif($infoKey eq "EXTRA" and $column->{"EXTRA"})
			{
				$field{$migrationKey} = 1
			}
			else
			{
				if(
					exists $field{$migrationKey} and
					not $field{$migrationKey} and
					$column->{$infoKey}
				)
				{
					next;
				}
				$field{$migrationKey} = $column->{$infoKey};
			}
		}
		push @fields, \%field;
	}
	my $tableComment = $self->tableComment($schemaName, $tableName);
	my $keys = $self->tableKeys($schemaName, $tableName);
	sprintf(
		$self->migrationTemplate($schemaName, $tableName, $tableComment),
		$self->templateFieldParts(\@fields),
		$self->templateKeyParts($keys)
	)
}

sub saveMigrationFile
{
	my($self, $schemaName, $tableName, $fbody) = @_;
	my $dir = $self->{"baseDir"};
	for my $name($self->config->{"dir"}{"table"}, $schemaName)
 	{	
		$dir .= "/" . $name;
		mkdir $dir, 0755 unless -d $dir;
	}
	my $path = $dir . "/" . $timeStamp . "_" . "$tableName.pl";
	my $fh = IO::File->new("> $path") or die "cannot write $path";
	print $fh $fbody;
	$fh->close and $path
}

sub showTables
{
	my($self, $schemaName) = @_;
	my $rows = $self->selectQuery(qq|SHOW TABLES|);
	my @result;
	for my $row(@$rows)
	{
		push @result, $row->{"Tables_in_$schemaName"}
	}
	\@result;
}

my $order = "ASC";

sub byDatetime
{
	$a =~ m!/(\d{14})_\w+\.pl$!;
	my $aDatetime = $1;
	$b =~ m!/(\d{14})_\w+\.pl$!;
	my $bDatetime = $1;
	$order eq "ASC" ? $aDatetime <=> $bDatetime : $bDatetime <=> $aDatetime
}

#
# 過去未来とも終端は含まない。
#
sub betweenDatetimes
{
	my($self, $dirs, $oldVersion, $newVersion) = @_;
	($oldVersion, $newVersion) = ($newVersion, $oldVersion) if $order eq "DESC";
	@$dirs = grep {
		m!/(\d{14})_\w+\.pl$!;
		(int($1) > $oldVersion and $newVersion > int($1)) ? 1 : 0
	} @$dirs;
}

sub findMigrations
{
	my($self, $fromVersion, $toVersion) = @_;
	$fromVersion = int $fromVersion;
	$toVersion   = int $toVersion;
	$order = $fromVersion > $toVersion ? "DESC" : "ASC";

	print CYAN;
	print $fromVersion > $toVersion ? "[DOWNGRADE]" : $fromVersion == $toVersion ? "[UP2DATE]" : "[UPGRADE]";
	say CLEAR;
	say "version ", $fromVersion, " -> ", $toVersion, "\n";

	my $parentDir = $self->{"baseDir"} . "/" . $self->config->{"dir"}{"table"};
	my @schemaDirs = glob "$parentDir/*";
	my @tableFilesAll;
	for my $schemaDir(@schemaDirs)
 	{
		my @tableFiles = glob "$schemaDir/*.pl";
		@tableFiles = grep { m!/\d{14}_\w+\.pl$! } @tableFiles;
		$self->betweenDatetimes(\@tableFiles, $fromVersion, $toVersion);
		push @tableFilesAll, @tableFiles;
	}
	@tableFilesAll = sort byDatetime @tableFilesAll;
	\@tableFilesAll
}

sub versionByFileName
{
	my($self, $filename) = @_;
	return unless $filename =~ /(\d{14})_(\w+)\.pl/;
	$1
}

sub classByFileName
{
	my($self, $filename) = @_;
	return unless $filename =~ /(\d{14})_(\w+)\.pl/;
	"Migration_$2_$1"
}

sub runMigrations
{
	my($self, $tableFiles, $lastVersion) = @_;
	my $method = $order eq "ASC" ? "up" : "down";
	my %dbhs;
	eval
	{
		for my $tableFile(@$tableFiles)
		{
			require $tableFile;
			my $class = $self->classByFileName($tableFile);
			$class->new(
				configBody => $self->config,
				dryrun     => $self->{"dryrun"},
				dbhs       => \%dbhs,
			)->$method or die "invalid return code";
			$lastVersion = $self->versionByFileName($tableFile) or die "invalid table-filename";
		}
		for my $schemaName(keys %dbhs)
		{
			$dbhs{$schemaName}->commit;
			$dbhs{$schemaName}->disconnect;
		}
	};
	if($@)
	{
		for my $schemaName(keys %dbhs)
		{
			if($dbhs{$schemaName} and $dbhs{$schemaName}->ping)
			{
				$dbhs{$schemaName}->rollback;
				$dbhs{$schemaName}->disconnect;
			}
		}
		say RED, "[ERROR] ", CLEAR, $@;
	}
	$order eq "ASC" ? $lastVersion ++ : $lastVersion--;
	$lastVersion
}

sub _log
{
	my($self) = @_;
	Fadi::Migration::Log->new(
		path => $self->{"baseDir"} . "/" .
				$self->config->{"dir"}{"log"} . "/" .
				$self->config->{"file"}{"log"}
	)
}

sub migrate
{
	my($self, $targetVersion, $dryrun) = @_;
	$self->{"dryrun"} = $dryrun ? 1 : 0;
	say "\n", YELLOW, "---DRYRUN---", CLEAR, "\n" if $self->{"dryrun"};
	$targetVersion = $self->getTargetVersion if(not defined $targetVersion or $targetVersion eq "now");
	$targetVersion .= "000000" if 8 == length $targetVersion;
	$self->usage("invalid params " . $targetVersion) if $targetVersion =~ /\D/;
	$self->usage("invalid params " . $targetVersion) if length $targetVersion != 14;

    my $currentVersion = $self->getCurrentVersion;
	my $tableFiles = $self->findMigrations($currentVersion, $targetVersion);
	if(not scalar @$tableFiles)
	{
		say "up to date ($currentVersion)";
		exit;
	}
	say CYAN, "[FILES]", CLEAR;
	say join("\n", @$tableFiles), "\n";
	my $lastVersion = $self->runMigrations($tableFiles, $currentVersion);
	$self->_log->write("$currentVersion -> $targetVersion");
	$self->setCurrentVersion($lastVersion) if $lastVersion;
}

sub migration
{
	my($self, $schemaName, $tableName) = @_;
	$self->connect($schemaName) or return $self->usage("cannot connect the database $schemaName");
	my $tableNames = defined $tableName ? [$tableName] : $self->showTables($schemaName);

	my $path;
	for my $tableName(@$tableNames)
	{
		my $columns = $self->tableColumns($schemaName, $tableName);
		if(not scalar @$columns)
		{
			say RED "Error: " . CLEAR . $schemaName . "." . $tableName . " is not found.";
			next;
		}
		my $fbody = $self->columns2struct($schemaName, $tableName, $columns);
		$path = $self->saveMigrationFile($schemaName, $tableName, $fbody);
	}
	say GREEN, "migration has successfully been created.\n", $path, CLEAR if $path;
}

sub seed
{
	my($self, @args) = @_;
	Fadi::Migration::Seeder->new(
		baseDir    => $self->{"baseDir"},
		configBody => $self->{"configBody"},
	)->run(@args);
}
sub cli
{
	my($self, %args) = @_;
	my $mode = shift @ARGV or return $self->usage;
	return $self->usage("unknown mode " . $mode) if not exists $modes{$mode};
	return $self->usage("set config path to cli.") if not exists $args{"config"};
	$self->{"baseDir"} = $args{"baseDir"};
	$self->{"configBody"} = $self->loadConfig($args{"config"});
	$self->$mode(@ARGV);
}

sub new
{
	my($self, %args) = @_;
	$timeStamp = getTargetVersion;
	bless \%args, $self
}

1

