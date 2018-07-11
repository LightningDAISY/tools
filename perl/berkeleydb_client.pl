#! /usr/bin/env perl
use Term::ANSIColor qw(:constants);
use strict;
use warnings;
use feature qw{ say };

my $defaultDirectory = "/Volumes/ramdisk/berkeley";

my $tool = BerkeleyDB::Access->new(
	dbDirectory => $defaultDirectory,

);
my $currentDirectory;
my $currentTable;

sub selectDirectory
{
	RETRYDIRECTORY:
	my $default = $tool->dbDirectory;
	print "Directory [$default]: ";
	my $in = <STDIN>;
	chomp $in;
	$in ||= $default;

	if(not -d $in)
	{
		say RED, "$in is not found", CLEAR;
		goto RETRYDIRECTORY;
	}
	$tool->dbDirectory($in);
	$in
}

sub createTable
{
	print "input new table-file name: ";
	my $in = <STDIN>;
	chomp $in;
	open my $fh, ">", $tool->dbDirectory . "/" . $in
		or die "cannot create " . $tool->dbDirectory . "/" . $in
	;
	close $fh
}

sub selectTable
{
	RETRYTABLE:
	my @dbFiles = glob($tool->dbDirectory . "/*");
	if(not scalar @dbFiles)
	{
		say RED, "directory " . $tool->dbDirectory . " is empty.", CLEAR;
		createTable;
		goto RETRYTABLE;
	}
	my $i = 0;
	for my $dbFile(@dbFiles)
	{
		++$i;
		if(-d $dbFile)
	   	{
			print BLUE,  "$i) ", CLEAR;
		}
		else
		{
			print GREEN, "$i) ", CLEAR;
		}
		say $dbFile;
	}
	say BLUE, "C) ", CLEAR, "Create new file.";
	print "Table-File number: ";
	my $in = <STDIN>;
	chomp $in;

	if($in eq "C")
	{
		createTable;
		goto RETRYTABLE;
	}
	goto RETRYTABLE if(
		not defined $in or 
		$in =~ /\D/ or 
		not length $in or
		$in < 1 or
		$in > $i
	);
	if(-d $dbFiles[--$in])
	{
		$tool->dbDirectory($dbFiles[$in]);
		goto RETRYTABLE;
	}
	$dbFiles[$in]
}

my %commands = (
	"keys" => {
		sort        => 1,
		description => "Show all keys",
	},
	"get" => {
		sort        => 2,
		description => " Get [GET KEY]",
	},
	"set" => {
		sort        => 3,
		description => " Set [SET KEY VALUE]",
	},
	"del" => {
		sort        => 4,
		description => " Remove [DEL KEY]",
	},
	"exit" => {
		sort => 99,
		description => " Finish [EXIT]",
	},
);

sub commandList
{
	RETRYCOMMAND:
	for my $cli(sort {$commands{$a}{"sort"} <=> $commands{$b}{"sort"}} keys %commands)
	{
		say GREEN, "$cli) ", CLEAR, $commands{$cli}{"description"};
	}
	print "input number (and a key): ";
	my $in = <STDIN>;
	chomp $in;
	goto RETRYCOMMAND if $in !~ /^(\w+)\s*(.*)/;
	+{
		command => $1,
		args    => $2,
	}
}

sub runCommand
{
	my($command, $args) = @_;
	if("keys" eq lc $command)
	{
		my $value;
		$tool->berkeleydb->get("XYZ", $value);
		say CYAN, join(", ", sort $tool->keysFile), CLEAR;
	}
	elsif("get" eq lc $command)
	{
		my $value;
		$tool->berkeleydb->get($args, $value);
		say defined $value ? (CYAN . $value . CLEAR)  : (YELLOW . "(empty)" . CLEAR);
	}
	elsif("set" eq lc $command)
	{
		my($key, $value) = split /\s+/, $args, 2;
		$tool->berkeleydb->put($key, $value);
		$tool->berkeleydb->sync;
	}
	elsif("del" eq lc $command)
	{
		$tool->berkeleydb->del($args);
		$tool->berkeleydb->sync;
		say "$args is removed";
	}
	elsif("exit" eq lc $command)
	{
		exit
	}
}

sub main
{
	$currentDirectory ||= selectDirectory;
	say GREEN, $currentDirectory, CLEAR;
	$currentTable ||= selectTable;
	$tool->dbPath($currentTable);
	say GREEN, $currentTable, CLEAR;
	say "";

	LOOPCOMMAND:
	my $input = commandList;
	runCommand(
		$input->{"command"},
		$input->{"args"},
	);
	goto LOOPCOMMAND;
}

main;

package BerkeleyDB::Access;
use DB_File;
use Fcntl;
use strict;
use warnings;

my %dbHash;
my $dbDirectory;
my $dbFile;
my $dbPath;
my $hashInfo = DB_File::HASHINFO->new;

my $berkeleydb;

sub berkeleydb
{
	my($self) = @_;

	$berkeleydb ||= tie(
		%dbHash,
		"DB_File",
		$self->dbPath,
		#O_CREAT|O_RDWR,
		O_RDWR,
		0666,
		DB_File::HASHINFO->new,
	);
}

sub dbDirectory
{
	my($self,$path) = @_;
	$dbDirectory = $path if defined $path;
	$dbDirectory
}

sub dbFile
{
	my($self,$path) = @_;
	$dbFile = $path if defined $path;
	$dbFile
}

sub dbPath
{
	my($self,$path) = @_;
	$dbPath = $path if defined $path;
	$dbPath ||= $dbDirectory . "/" . $dbFile;
	$dbPath
}

sub keysFile
{
	my($self) = @_;
	keys %dbHash
}

#
# my $ins = BerkeleyDB::Access->new(
# 	"dbDirectory" => "/Volume/ramdisk/berkeleydb"
# );
#
sub new
{
	my($class, %args) = @_;
	$dbDirectory = $args{"dbDirectory"};
	bless \%args, $class
}


1

__END__
