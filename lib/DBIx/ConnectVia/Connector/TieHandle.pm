package DBIx::ConnectVia::Connector::TieHandle;
use strict;
use warnings;

# ABSTRACT - DBIx::ConnectVia::Connector dbh backing obj
# VERSION
# AUTHORITY

use DBIx::Connector;

sub TIEHASH {
  my $class = shift;
  my %args = @_;
  my $connect_info = $args{connect_info};
  my $connector = DBIx::Connector->new(@$connect_info);

  my $self = {
    connector => $connector
  };

  bless $self, $class;
}

sub connector {
  my $self = shift;
  $self->{connector};
}

sub FETCH {
  my $self = shift;
  my $key = shift;
  $self->connector->dbh->{$key};
}

sub STORE {
  my $self = shift;
  my ($key, $value) = @_;
  $self->connector->dbh->{$key} = $value;
}

sub FIRSTKEY {
  my $self = shift;
  my $dbh = $self->connector->dbh;
  keys %$dbh; # Reset iterator
  each %$dbh;
}

sub NEXTKEY {
  my $self = shift;
  my $dbh = $self->connector->dbh;
  each %$dbh;
}

1;
