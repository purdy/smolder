package Smolder::RDB::ProjectManager;

use strict;

use base 'Rose::DB::Object::Manager';

use lib '/var/www/lib';

sub object_class { 'Smolder::RDB::Project' }

__PACKAGE__->make_manager_methods( 'projects' );

1;
