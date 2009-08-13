package Smolder::RDB::Project;

use strict;
use warnings;

use Smolder::RDB;

use base qw( Rose::DB::Object );

__PACKAGE__->meta->setup(
    table   => 'project',
    columns => [
        id   => { type => 'serial', primary_key => 1, not_null => 1 },
        name => { type => 'text',   not_null    => 1 },
        start_date => { type => 'int', not_null => 1 },
        public           => { type => 'int',  default => 1 },
        enable_feed      => { type => 'int',  default => 1 },
        default_platform => { type => 'text', default => '' },
        default_arch     => { type => 'text', default => '' },
        graph_start      => { type => 'text', default => 'project' },
        allow_anon       => { type => 'int',  default => 0 },
        max_reports      => { type => 'int',  default => 100 },
        extra_css        => { type => 'text', default => '' },
    ],
    unique_key => 'name',

    relationships   => [
        developers    => {
            type        => 'many to many',
            map_class   => 'Smolder::RDB::ProjectDeveloper',
            map_from    => 'project',
            map_to      => 'developer',
        },
    ],
);

sub init_db { Smolder::RDB->new }

1;
__END__
CREATE TABLE project (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    name                TEXT NOT NULL,
    start_date          INTEGER NOT NULL,
    public              INTEGER DEFAULT 1,
    enable_feed         INTEGER DEFAULT 1,
    default_platform    TEXT DEFAULT '',
    default_arch        TEXT DEFAULT '',
    graph_start         TEXT DEFAULT 'project',
    allow_anon          INTEGER DEFAULT 0,
    max_reports         INTEGER DEFAULT 100,
    extra_css           TEXT DEFAULT ''
);

CREATE UNIQUE INDEX i_project_name_project on project (name);
