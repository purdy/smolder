package Smolder::RDB::PreferenceManager;

use strict;

use base 'Rose::DB::Object::Manager';

use lib '/var/www/lib';

sub object_class { 'Smolder::RDB::Preference' }

__PACKAGE__->make_manager_methods( 'preferences' );

1;
