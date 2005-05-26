package Locale::MakePhrase::BackingStore::PostgreSQL;
our $VERSION = 0.1;
our $DEBUG = 0;

=head1 NAME

Locale::MakePhrase::BackingStore::PostgreSQL - Retrieve translations
from a table within a PostgreSQL database.

=head1 DESCRIPTION

This backing store is capable of loading language rules from a
PostgreSQL database table, which conforms to the structure defined
below.

It assumes that the database is configured to use UNICODE as the
text storage mechanism (ie: 'psql -l' should should you how the
database instance was created).

Unlike the file-based implementations, this module will hit the
database looking for language translations, every time the language
rules are requested.  This allows you to update the database (say
via a web interface), immediately using the new translations.

=head1 TABLE STRUCTURE

The table structure can be created with the following PostgreSQL
SQL statement:

  CREATE TABLE some_table (
    key text,
    language text,
    expression text,
    priority integer,
    translation text
  );

As you can see, there is not much to it.

Upon construction, this module will try to connect to the database
to confirm that the table exists and has a suitable structure.  If
it hasn't, this module will die.

=head1 API

The following functions are implemented:

=cut

use strict;
use warnings;
use utf8;
use Data::Dumper;
use DBI;
use DBD::Pg;
use base qw(Locale::MakePhrase::BackingStore);
use Locale::MakePhrase::Utils qw(die_from_caller);
our $default_connect_options = {
  RaiseError => 1,
  AutoCommit => 1,
  ChopBlanks => 1,
  pg_enable_utf8 => 1,  # assumes database is using UNICODE
};
our $implicit_table_structure = "key,language,expression,priority,translation";
$Data::Dumper::Indent = 1 if $DEBUG;

#--------------------------------------------------------------------------

=head2 $self init([...])

You will need to specify some of these options:

=over 2

=item C<table>

The name of the table that implements the table structure shown
above.  Note you can add more database fields if necessary; then by
overloading either C<get_query> or C<get_where>. you can make use of
the extra fields.

=item C<dbh>

You can supply a pre-connected L<DBI> handle, rather than supply the
connection parameters.

=item C<owned>

If you supply a database handle, you should specify whether you want
this module to take ownership of the handle.  If so, it will disconnect
the database handle on destruction.

=item C<host>

=item C<port>

=item C<user>

=item C<password>

By specifying these four options (rather than the C<dbh>), this module
will connect to the database using these options.  Note that C<host>
defaults to 'localhost', C<port> defaults to '5432', C<user> and
C<password> defaults to empty (just in case you dont supply any 
connection parameters).

=item C<connect_options>

The default PostgreSQL connections options are:

  RaiseError => 1
  AutoCommit => 1
  ChopBlanks => 1
  pg_enable_utf8 => 1

If you set this value, you must supply a hash_ref supplying the
appropriate PostgreSQL connection options.

=back

Notes: you must specify either the C<dbh> option, or suitable connection
options.

=cut

sub init {
  my $self = shift;

  # get options
  my %options;
  if (@_ > 1 and not(@_ % 2)) {
    %options = @_;
  } elsif (ref($_[0]) eq 'HASH') {
    %options = %{$_[0]};
  } else {
    die_from_caller("Invalid arguments passed to new()");
  }
  print STDERR "Arguments to ". ref($self) .": ". Dumper(\%options) if $DEBUG > 5;
  die_from_caller("Missing 'table' argument") unless $options{table};
  $self->{table} = $options{table};
  delete $options{table};

  # connect to database - if user passed in a database handle, use it
  my $dbh;
  if ($options{dbh}) {
    $dbh = $options{dbh};
    delete $options{dbh};
    $self->{owned} = $options{owned} ? 1 : 0;
    delete $options{owned};

    # make sure this handle is a valid database handle
    die_from_caller("Database handle is not real?") unless (ref($dbh) and $dbh->can('ping') and $dbh->ping());

  # otherwise, make a specific database handle.. and since we
  # constructed the database handle -> we definately need to destroy it
  } else {

    die_from_caller("Missing 'database' argument") unless $options{database};
    $options{host} = "localhost" unless $options{host};
    $options{port} = "5432" unless $options{port};
    $options{user} = "" unless $options{user};
    $options{password} = "" unless $options{password};

    $dbh = $self->_connect(\%options);
    $self->{owned} = 1;
  }

  # test database connection for table structure
  $self->_test_table_structure($dbh);

  # all is good...
  $self->{dbh} = $dbh;
  return $self;
}

#--------------------------------------------------------------------------

=head2 $dbh dbh()

Returns the database connection handle

=cut
sub dbh { shift->{dbh} }

#--------------------------------------------------------------------------

=head2 void set_owned(boolean)

Set/clear ownership on the database handle.

=cut
sub set_owned {
  my $self = shift;
  my $owned = shift;
  $self->{owned} = $owned ? 1 : 0;
}

#--------------------------------------------------------------------------

=head2 \@rule_objs get_rules($contect,$key,\@languages)

Retrieve the translations from the database, using the selected languages.
The implementation will fetch the language rule properties each time
this is called, so that if the database gets updated, the next call will
use the new properties.

=cut

sub get_rules {
  my ($self,$context,$key,$languages) = @_;
  my $table = $self->{table};
  my $dbh = $self->{dbh};
  my @translations;

  # ensure connection is good...
  $dbh->ping() or $dbh = $self->_reconnect($dbh);

  # setup query
  my $qry = $self->get_query($table,$context,$languages);
  print STDERR "Using query: $qry\n" if $DEBUG > 4;
  my $sth = $dbh->prepare($qry);
  my $rv = $sth->execute($key);
  return undef unless (defined $rv and $rv > 0);
  my ($k,$language,$expression,$priority,$translation);
  $sth->bind_columns(\$k,\$language,\$expression,\$priority,\$translation);

  # make rules for each result
  while ($sth->fetch()) {
    push @translations, $self->make_rule(
      key => $key,
      language => $language,
      expression => $expression, 
      priority => $priority,
      translation => $translation
    );
  }

  print STDERR "Found translations:\n", Dumper(\@translations) if $DEBUG;
  return \@translations;
}

#--------------------------------------------------------------------------

=head2 $string get_query($table,$context,\@languages)

Some circumstances allow the generic SQL statement to be used to query
the database.  However, in some cases you may want to do something
unusual...  By sub-classing this module, you can create your own
specific SQL statement.

=cut

sub get_query {
  my ($self,$table,$context,$languages) = @_;
  my $qry = join(' OR ', map("lower(language) = '$_'", @$languages) );
  $qry = "SELECT $implicit_table_structure FROM $table WHERE key = ? AND ($qry)";
  if ($context) {
    $qry .= " AND context = '$context'";
  } else {
    $qry .= " AND (context IS NULL OR context = '')";
  }
  my $custom = $self->get_where();
  $qry .= " AND $custom" if $custom;
  return $qry;
}

#--------------------------------------------------------------------------

=head2 $string get_where()

Under some circumstances the generic C<get_query()> command will generate
an SQL statement that is mostly correct, but needs minor adjustment.  By
overloading this method, you can _add to_ the existing SQL statement.

If you want to know what this does, you should probably read the source
code for this module.

=cut

sub get_where { "" }

#--------------------------------------------------------------------------
#
# If this module created its own database handle (or the user wants
# this module to own the handle), we need to clean up on destruction
#
sub DESTROY {
  my $self = shift;
  if ($self->{owned} && $self->{dbh}) {
    $self->{dbh}->disconnect();
    delete $self->{dbh};
    delete $self->{owned};
  }
}

#--------------------------------------------------------------------------
# The following methods are not part of the API - they are private.
#
# This means that everything above this code-break is allowed/designed
# to be overloaded.
#--------------------------------------------------------------------------

#--------------------------------------------------------------------------
#
# Connect to database using specified connection options
#
sub _connect {
  my ($self,$options) = @_;

  my $connect_string = "dbi:Pg:dbname=". $options->{database} .";host=". $options->{host} .";port=". $options->{port};
  my $connect_options = $default_connect_options;
  $connect_options = $options->{connect_options} if exists $options->{connect_options};

  # try connecting to database
  my $dbh;
  eval { $dbh = DBI->connect($connect_string,$options->{user},$options->{password},$connect_options); };
  die_from_caller("Failed to connect to database:\n- connect string: $connect_string\n- user: ". $options->{user} ."\n- password: ". $options->{password} ."\n- connect options: ". Dumper($connect_options) ."\nError info:\n$@\n") if ($@);

  $self->{database} = $options->{database};
  $self->{host} = $options->{host};
  $self->{port} = $options->{port};
  $self->{user} = $options->{user};
  $self->{password} = $options->{password};
  $self->{connect_options} = $connect_options;
  return $dbh;
}

#--------------------------------------------------------------------------
#
# Test the structure of the database table -> need to make sure that
# the table is capable of performing the table-lookups.
#
sub _test_table_structure {
  my ($self,$dbh) = @_;

  # make sure user specified table exists
  eval {
    my $qry = "SELECT 1 FROM ". $self->{table} ." LIMIT 1";
    my $sth = $dbh->prepare($qry);
    $sth->execute();
  };
  if ($@) {
    $dbh->disconnect() if ($self->{owned} and $dbh);
    die_from_caller("Table '". $self->{table} ."' doesn't exist");
  }

  # make sure user specified table has (at least) the minimum correct structure
  eval {
    my $qry = "SELECT $implicit_table_structure FROM ". $self->{table} ." LIMIT 1";
    my $sth = $dbh->prepare($qry);
    $sth->execute();
  };
  if ($@) {
    $dbh->disconnect() if ($self->{owned} and $dbh);
    die_from_caller("Table ". $self->{table} ." doesn't conform to implicit table structure: $implicit_table_structure");
  }
}

#--------------------------------------------------------------------------
#
# Sometimes the database will dissappear (possibly due to it re-starting...).
# As such, we need to reconnect to the database, as the current database handle
# is invalid.
#
sub _reconnect {
  my ($self,$dbh) = @_;

  # Make sure that we own the database handle
  die_from_caller("The database connection has failed for some reason... I cannot reconnect as I dont own the database handle...") unless $self->{owned};

  # cleanup handle
  $dbh->disconnect() if $dbh;
  undef $dbh;

  # reconnect to database
  my $options;
  $options->{database} = $self->{database};
  $options->{host} = $self->{host};
  $options->{port} = $self->{port};
  $options->{user} = $self->{user};
  $options->{password} = $self->{password};
  $options->{connect_options} = $self->{connect_options};
  $dbh = $self->_connect($options);

  # test database table structure
  $self->_test_table_structure($dbh);

  # all is good...
  $self->{dbh} = $dbh;
  return $dbh;
}

1;
__END__
#--------------------------------------------------------------------------

=head1 TODO

Re-implement this module so as to database agnostic, moving the
PostgreSQL specific code into a sub-class.

=cut

