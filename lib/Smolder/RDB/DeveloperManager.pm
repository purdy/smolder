package Smolder::RDB::DeveloperManager;

use strict;

use base 'Rose::DB::Object::Manager';

use lib '/var/www/lib';

sub object_class { 'Smolder::RDB::Developer' }

__PACKAGE__->make_manager_methods( 'developers' );

1;
