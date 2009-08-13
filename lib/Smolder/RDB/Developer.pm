package Smolder::RDB::Developer;

use strict;
use warnings;

use Smolder::RDB;

use base qw( Rose::DB::Object );

__PACKAGE__->meta->setup(
    table   => 'developer',
    columns => [
        id         => { type => 'serial', primary_key => 1, not_null => 1 },
        username   => { type => 'text',   default     => '' },
        fname      => { type => 'text',   default     => '' },
        lname      => { type => 'text',   default     => '' },
        email      => { type => 'text',   default     => '' },
        password   => { type => 'text',   default     => '' },
        admin      => { type => 'int',    default     => 0 },
        preference => { type => 'int',    not_null    => 1 },
        guest      => { type => 'int',    default     => 0 },
    ],
    unique_key => 'username',
    foreign_keys    => [
        preference => {
            class       => 'Smolder::RDB::Preference',
            key_columns => { preference => 'id' },
        },
    ],
    relationships   => [
        smoke_reports   => {
            type        => 'one to many',
            class       => 'Smolder::RDB::SmokeReport',
            column_map  => { id => 'developer' },
        },
        projects    => {
            type        => 'many to many',
            map_class   => 'Smolder::RDB::ProjectDeveloper',
            map_from    => 'developer',
            map_to      => 'projects',
        },
    ],
);

=head3 project_pref

Given a L<Smolder::DB::Project> object, this returns the L<Smolder::DB::Preference>
object associated with that project and this Developer.

=cut

sub project_pref {
    my ($self, $project) = @_;
    my $preferences = Smolder::RDB::PreferenceManager->get_preferences(
        require_objects => [ 'project_developers' ],
        query   => [
            developer   => $self->id,
            project     => $project->id,
        ]
    );
#    my $sth = $self->db_Main->prepare_cached(
#        qq(
#SELECT preference.* FROM preference, project_developer
#WHERE preference.id = project_developer.preference
#AND project_developer.developer = ?
#AND project_developer.project = ?
#)
#    );
#    $sth->execute($self->id, $project->id);

    # there should be only one, but it returns an iterator unless
    # in list context
    #my @prefs = Smolder::DB::Preference->sth_to_objects($sth);
    #return $prefs[0];
    return $preferences->[0];
}

sub init_db { Smolder::RDB->new }

1;
__END__
CREATE TABLE developer (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    username    TEXT DEFAULT '',
    fname       TEXT DEFAULT '',
    lname       TEXT DEFAULT '',
    email       TEXT DEFAULT '',
    password    TEXT DEFAULT '',
    admin       INTEGER DEFAULT 0,
    preference  INTEGER NOT NULL,
    guest       INTEGER DEFAULT 0,
    CONSTRAINT 'fk_developer_preference' FOREIGN KEY ('preference') REFERENCES 'preference' ('id')
);

CREATE INDEX i_preference_developer on developer (preference);
CREATE UNIQUE INDEX unique_username_developer on developer (username);

INSERT INTO developer (id, username, fname, lname, email, password, admin, preference, guest) VALUES (1, 'admin', 'Joe', 'Admin', 'test@test.com', 'YhKDbhvT1LKkg', 1, 1, 0);
INSERT INTO developer (id, username, fname, lname, email, password, admin, preference, guest) VALUES (2, 'anonymous', '', '', '', '', 0, 2, 1);
