package Smolder::RDB::SmokeReportTag;

use strict;
use warnings;

use Smolder::RDB;

use base qw( Rose::DB::Object );

__PACKAGE__->meta->setup(
    table   => 'smoke_report_tag',
    columns => [
        id => { type => 'serial', not_null => 1, primary_key => 1 },
        smoke_report => { type => 'int',  not_null => 1 },
        tag          => { type => 'text', default  => '' },
    ],
    foreign_keys => [
        smoke_report => {
            class       => 'Smolder::RDB::SmokeReport',
            key_columns => { project => 'id' },
        },
    ],
);

sub init_db { Smolder::RDB->new }

1;
__END__
CREATE TABLE smoke_report_tag  (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    smoke_report    INTEGER NOT NULL,
    tag             TEXT DEFAULT '',
    CONSTRAINT 'fk_smoke_report_tag_smoke_report' FOREIGN KEY ('smoke_report') REFERENCES 'smoke_report' ('id') ON DELETE CASCADE
);
