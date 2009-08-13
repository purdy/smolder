package Smolder::RDB;

use strict;
use warnings;
use base qw( Rose::DB );
use Smolder::Conf qw(SQLDir DataDir);
use File::Spec::Functions qw(catfile);
use DateTime::Format::Strptime;

__PACKAGE__->use_private_registry;

__PACKAGE__->register_db(
    driver          => 'SQLite',
    database        => __PACKAGE__->db_file(),
    #server_time_zone    => 'America/New_York',
);

=head2 db_file

Returns the full path to the SQLite DB file.

=cut

sub db_file {
    return catfile(DataDir, "smolder.sqlite");
}

=head2 create_database

This method will create a brand new, completely empty database file for Smolder.

Smolder::DB->create_database();

=cut

sub create_database {
    my $class = shift;
    my $file = $class->db_file();

    # create a new file by this name whether it exists or not
    open(FH, ">$file") or die "Could not open file '$file' for writing: $!";
    close(FH) or die "Could not close file '$file': $!";

    my @files = glob(catfile(SQLDir, '*.sql'));
    foreach my $f (@files) {
        eval { $class->run_sql_file($f) };
        die "Couldn't load SQL file $f! $@" if $@;
    }

    # Set the db_version
    my $version = $Smolder::VERSION;
    my $db = Smolder::RDB->new;
    my $dbh = $db->dbh or die $db->error;
    eval { $dbh->do("UPDATE db_version set db_version=$version") };
    die "Could not update db_version! $@" if $@;
}

=head2 run_sql_file

Given the runs the SQL contained in the file against out SQLite DB

Smolder::DB->run_sql_file('/usr/local/smolder/foo.sql');

=cut

sub run_sql_file {
    my ($class, $file) = @_;
    open(my $IN, $file) or die "Could not open file '$file' for reading: $!";

    my $db = Smolder::RDB->new;
    my $dbh = $db->dbh or die $db->error;

    my $sql = '';

    # read each line
    while (my $line = <$IN>) {

        # skip comments
        next if ($line =~ /^--/);
        $sql .= $line;

        # if we have a ';' at the end of the line then it should
        # be the end of the statement
        if ($line =~ /;\s*$/) {
            $dbh->do($sql)
              or die "Could not execute SQL '$sql': $!";
            $sql = '';
        }
    }

    close($file);
}


1;
