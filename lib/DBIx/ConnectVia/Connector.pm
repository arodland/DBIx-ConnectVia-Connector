package DBIx::ConnectVia::Connector;
use strict;
use warnings;

# ABSTRACT: Use DBIx::Connector like it was Apache::DBI
# VERSION
# AUTHORITY

use DBIx::ConnectVia::Connector::TieHandle;

sub import {
  $DBI::connect_via = __PACKAGE__ . "::_connect";
}

# This is called from DBI->connect because of $DBI::connect_via
# The first line is cargo cult -- supposedly in some situation that probably
# hasn't happened in a decade, the first arg will be an un-blessed driver name.
# The remaining args are a driver handle, the DSN *minus* "dbi:DriverName:",
# username, passsword, and attr hash.
sub _connect {
  shift unless ref $_[0];
  my $drh = $_[0];

  # When the user calls DBI->connect, we want to wrap it in a proxy object
  # that will send things through DBIx::Connector.
  # When DBIx::Connector calls DBI->connect, we want to actually let it
  # connect to the DB, not get into an infinite loop.
  my $i = 0;
  while (my @frame = caller($i)) {
    if ($frame[0] eq 'DBIx::Connector') {
      my $connect_method = $drh->can('connect');
      goto $connect_method;
    }
    $i++;
  }

  (undef, my @connect_info) = @_;
  $connect_info[0] = "dbi:$drh->{Name}:" . $connect_info[0];
  return __PACKAGE__->instance(connect_info => \@connect_info);
}

my %Handles;

# This is the caching bit -- if we already have a proxy handle for this
# DSN/user/pass combo then return it. If we don't, then make one up and
# save it for later.
# The connector itself will handle reinitializing the DB connection if
# the PID or TID changes, so we don't need to clear the cache ourself
# in that case.
sub instance {
  my $class = shift;
  my %args = @_;
  my $connect_info = $args{connect_info};

  # DSN, user, pass. Same as Apache::DBI.
  my $key = join $;, @{$connect_info}[0..2];
  if (!$Handles{$key}) {
    my $self = {};
    tie %$self, 'DBIx::ConnectVia::Connector::TieHandle', @_;
    bless $self, $class;
    $Handles{$key} = $self;
  }

  return $Handles{$key};
}

sub connector {
  my $self = shift;
  (tied %$self)->connector(@_);
}

my $make_proxy = sub {
  my $method = shift;

  return sub {
    my $self = shift;
    my @args = @_;
    (tied %$self)->connector->run(fixup => sub { $_->$method(@args) });
  };
};

sub AUTOLOAD {
  my $self = shift;
  (my $method = our $AUTOLOAD) =~ s/.*://;
  return if $method eq 'DESTROY';
  my $code = $make_proxy->($method);
  return $self->$code(@_);
}

sub can {
  my $self = shift;
  if (my $super_can = $self->SUPER::can(@_)) {
    return $super_can;
  }

  my $method = shift;
  return $make_proxy->($method);
}

1;
