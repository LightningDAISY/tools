#! /usr/bin/env perl
use strict;
use warnings;
use IO::Socket::INET;
use IO::Select;
use feature qw{ say };

my $server;
my $ioh;

my %bodiesByPath = (
	"/"     => qq|<p>index</p>|,
	"/test" => qq|<p>test</p>|,
	"/set"  => qq|<p>set cookie</p>|,
);

#
# set-cookieのdomainには現在参照中のドメインのみ設定できます。
# 無関係なサーバでfacebookのcookieをでっち上げることは原則できませんが
# hostsで一時的に書き換えればでっち上げられます。
#
my %headersByPath = (
	"/set" => {
		"Set-Cookie" => {
			"session_id" => "xxxxxx",
			"domain"     => "localhost",
			"path"       => "/",
			"expires"    => "Tue, 19 Jan 2038 03:14:07 GMT",
		},
	},
);

sub start
{
	$server = IO::Socket::INET->new(
		LocalAddr => "127.0.0.1",
		LocalPort => 65530,
		Proto     => "tcp",
		Listen    => 3,
		ReuseAddr => 1,
	) or die $!;

	$server->listen or die $!;
	$server
}

my %responseMessages = (
	"200" => "OK",
	"404" => "NOT FOUND",
);

sub headerByPath
{
	my($path) = @_;
	return if not exists $headersByPath{$path};
	my @headers;
	for my $key(keys %{$headersByPath{$path}})
	{
		if("HASH" eq ref $headersByPath{$path}{$key})
		{
			my @strings;
			my $stringValue = "";
			for my $name(keys %{$headersByPath{$path}{$key}})
			{
				next if $name eq "domain" or $name eq "path" or $name eq "expires";
				push @strings, sprintf("%s=%s", $name, $headersByPath{$path}{$key}{$name});
			}
			for my $name(qw{domain path expires})
			{
				push @strings, sprintf("%s=%s", $name, $headersByPath{$path}{$key}{$name})
					if exists $headersByPath{$path}{$key}{$name}
				;
			}
			push @headers, sprintf("%s: %s", $key, join ";", @strings);
		}
		else
		{
			push @headers, sprintf("%s: %s", $key, $headersByPath{$path}{$key});
		}
	}
	return if not scalar @headers;
	join "\r\n", @headers
}

sub bodyByPath
{
	my($path) = @_;
	$path =~ s!(.)/$!$1!;
	exists $bodiesByPath{$path} ? $bodiesByPath{$path} : undef
}

sub finish
{
	$server->close;
}

#
# GET / HTTP/1.1
#
sub sayStatus
{
	my($protocol, $statusCode) = @_;
	printf $ioh "%s %d\r\n", $protocol, $statusCode;
}

sub sayContentType
{
	my($type) = @_;
	print $ioh "Content-type: $type\r\n";
}

sub sayResponseHeader
{
	my($header) = @_;
	print $ioh $header, "\r\n";
}

sub sayResponseBody
{
	my($body) = @_;
	my $bodyUtf8 = $body;
	utf8::is_utf8($bodyUtf8) or utf8::decode($bodyUtf8);
	print $ioh "Content-Length: ", length($bodyUtf8), "\r\n\r\n", $body;
}

sub headersAndBody
{
	$ioh->blocking(0);

	# headers
	my %headers;
	while(my $line = <$ioh>)
	{
		$line =~ tr/\r\n//d;
		last if not length $line;
		my($key,$value) = split /:\s*/, $line;
		$headers{$key} = $value;
	}

	# body
	my $body = "";
	while(my $line = <$ioh>)
	{
		$body .= $line . "\n";
	}
	(\%headers, $body)
}

sub requestQuery
{
	my $query = <$ioh>;
	my($method, $path, $protocol) = split /\s+/, $query;
	($method, $path, $protocol)
}

sub child
{
	my($method, $path, $protocol) = requestQuery;
	my($headers, $reqBody) = headersAndBody;
	my $resBody   = bodyByPath($path);
	my $resHeader = headerByPath($path);
	my $resCode = defined($resBody) ? 200 : 404;
	sayStatus($protocol, $resCode);
	sayContentType("text/html");
	sayResponseHeader($resHeader) if defined $resHeader;
	sayResponseBody($resBody);
	exit;
}

sub parent
{
	while(my $handler = $server->accept)
	{
		fork and next;
		$ioh = $handler;
		child;
	}
}

start;
parent;
finish;

__END__

あるPathへのリクエストで、ある決まった応答を返すHTTPサーバです。
APIのスタブとして使います。

  my %bodiesByPath = (
  	"/"     => qq|<p>index</p>|,
  	"/test" => qq|<p>test</p>|,
  	"/set"  => qq|<p>set cookie</p>|,
  );

上が応答の設定です。
/ と /test と /set で決まった応答を返します。他は404です。

  my %headersByPath = (
  	"/set" => {
  		"Set-Cookie" => {
  			"session_id" => "xxxxxx",
  			"domain"     => "localhost",
  			"path"       => "/",
  			"expires"    => "Tue, 19 Jan 2038 03:14:07 GMT",
  		},
  	},
  );

上は /set へのアクセス時のみSet-Cookieする設定です。

