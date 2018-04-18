#! /usr/bin/env perl
use strict;
use warnings;
use feature qw{ say };

sub byVersion
{
	my @splitedA = split /([\d\.]+?)\.?/, $a;
	my @splitedB = split /([\d\.]+?)\.?/, $b;

	for(my $i=0; $i<=$#splitedA; $i++)
	{
 		if($splitedA[$i] ne $splitedB[$i])
		{
			if($splitedA[$i] =~ /[\d\.]+/ and $splitedB[$i] =~ /[\d\.]+/)
			{
				
				return $splitedA[$i] <=> $splitedB[$i]
			}
			return $splitedA[$i] cmp $splitedB[$i]
		}	
	}
	$a cmp $b
}

my @files = (
	"scala2.2.5.zip",
	"scala0.9.1.zip",
	"scala1.5.5.zip",
	"scala3.8.8.zip",
	"scala0.2.2.zip",
	"scala2.2.2.zip",
);

my @sorted = sort byVersion @files;
say join ", ", @sorted;

