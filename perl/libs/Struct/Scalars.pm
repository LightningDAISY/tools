package Struct::Scalars;
use strict;
use warnings;

sub recursive
{
  my($self, $ref) = @_;
  if("HASH" eq ref $ref)
  {
    my %result;
    for my $key(keys %$ref)
    {
      my $newKey = $self->recursive($key);
      $result{$newKey} = $self->recursive($ref->{$key});
    }
    \%result
  }
  elsif("ARRAY" eq ref $ref)
  {
    my @result;
    for my $value(@$ref)
    {
      push @result, $self->recursive($value)
    }
    \@result
  }
  elsif("CODE" eq ref $ref)
  {
    $self->{"code"}->($ref->())
  }
  elsif("" eq ref $ref)
  {
    $self->{"code"}->($ref)
  }
  else
  {
    $ref
  }
}

sub modify
{
  my($self, $code) = @_;
  $self->{"code"} = $code;
  $self->recursive($self->{"struct"})
}

sub new
{
  my($class, $ref) = @_;
  bless +{ struct => $ref }, $class
}

1

__END__

  my $unknownStruct = +{
    a => {
      a1 => [
        "a11", "a12", "a13",
      ]
    }
  };
  my $ins = Struct::Scalars->new($unknownStruct);
  my $modified = $ins->modify(sub {
    my($str) = @_;
    "--$str--"
    #utf8::is_utf8 $str or utf8::decode $str;
    #$str
  });

