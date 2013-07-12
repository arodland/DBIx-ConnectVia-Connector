use Test::More::Fork;
use DBI;
use DBD::SQLite;

use_ok 'DBIx::ConnectVia::Connector';

my $DSN = "dbi:SQLite:dbname=:memory:";

my $dbh = DBI->connect($DSN, "", "");

is ref($dbh), "DBIx::ConnectVia::Connector", "dbh is a ConnectVia";
is ref(tied(%$dbh)), "DBIx::ConnectVia::Connector::TieHandle", "dbh is tied";

$dbh->do("create table foo (id integer)");

my $magic = int rand 2**30;
$dbh->do("insert into foo (id) values (?)", undef, $magic);

my ($check) = $dbh->selectrow_array("select id from foo");
is $check, $magic, "retrieved a value";

my $dbh2 = DBI->connect($DSN, "", "");

is $dbh, $dbh2, "A new handle to the same DSN seems to be the same handle";

($check) = $dbh2->selectrow_array("select id from foo");
is $check, $magic, "got the same value again";

fork_tests {
  ($check) = $dbh2->selectrow_array("select * from sqlite_master");
  ok !defined($check), "we get a new handle after fork";
};

done_testing;
