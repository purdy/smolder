package Smolder::RDB::ProjectDeveloper;

use strict;
use warnings;

use Smolder::RDB;

use base qw( Rose::DB::Object );

__PACKAGE__->meta->setup(
    table   => 'project_developer',
    columns => [
        project    => { type => 'int', not_null => 1 },
        developer  => { type => 'int', not_null => 1 },
        preference => { type => 'int' },
        admin      => { type => 'int', default  => 0 },
        added      => { type => 'int', default  => 0 },
    ],
    primary_key_columns => [ 'project', 'developer' ],
    foreign_keys        => [
        project => {
            class       => 'Smolder::RDB::Project',
            key_columns => { project => 'id' },
        },
        developer => {
            class       => 'Smolder::RDB::Developer',
            key_columns => { developer => 'id' },
        },
        preference => {
            class       => 'Smolder::RDB::Preference',
            key_columns => { preference => 'id' },
        },
    ],
);

sub init_db { Smolder::RDB->new }

1;
__END__
CREATE TABLE project_developer (
    project     INTEGER NOT NULL,
    developer   INTEGER NOT NULL,
    preference  INTEGER,
    admin       INTEGER DEFAULT 0,
    added       INTEGER DEFAULT 0,
    PRIMARY KEY (project, developer),
    CONSTRAINT 'fk_project_developer_project' FOREIGN KEY ('project') REFERENCES 'project' ('id') ON DELETE CASCADE,
    CONSTRAINT 'fk_project_developer_developer' FOREIGN KEY ('developer') REFERENCES 'developer' ('id') ON DELETE CASCADE,
    CONSTRAINT 'fk_project_developer_preference' FOREIGN KEY ('preference') REFERENCES 'preference' ('id')
);

CREATE INDEX i_developer_project_developer on project_developer (developer);
CREATE INDEX i_project_project_developer on project_developer (project);
CREATE INDEX i_preference_project_developer on project_developer (preference);
