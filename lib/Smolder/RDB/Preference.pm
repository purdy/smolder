package Smolder::RDB::Preference;

use strict;
use warnings;

use Smolder::RDB;

use base qw( Rose::DB::Object );

__PACKAGE__->meta->setup(
    table   => 'preference',
    columns => [
        id => { type => 'serial', primary_key => 1, not_null => 1 },
        email_type           => { type => 'text', default => 'full' },
        email_freq           => { type => 'text', default => 'on_new' },
        email_limit          => { type => 'int',  default => 0 },
        email_sent           => { type => 'int',  default => 0 },
        email_sent_timestamp => { type => 'datetime' },
    ],
    relationships   => [
        project_developers  => {
            type        => 'one to many',
            class       => 'Smolder::RDB::ProjectDeveloper',
            column_map  => { id => 'preference' },
        },
    ],
);

sub init_db { Smolder::RDB->new }

1;
__END__
CREATE TABLE preference (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    email_type  TEXT DEFAULT 'full',
    email_freq  TEXT DEFAULT 'on_new',
    email_limit INT DEFAULT 0,
    email_sent  INT DEFAULT 0,
    email_sent_timestamp INTEGER
);

INSERT INTO preference (id) VALUES (1);
INSERT INTO preference (id) VALUES (2);
