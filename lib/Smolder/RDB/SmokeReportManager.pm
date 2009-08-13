package Smolder::RDB::SmokeReportManager;

use strict;

use base 'Rose::DB::Object::Manager';

use lib '/var/www/lib';

sub object_class { 'Smolder::RDB::SmokeReport' }

__PACKAGE__->make_manager_methods( 'smoke_reports' );

1;
