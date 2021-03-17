#!/usr/bin/perl

# Copyright 2015 Koha Development team
#
# This file is part of Koha
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Test::More tests => 4;

use Koha::MarcModificationTemplate;
use Koha::MarcModificationTemplates;
use Koha::Database;

use t::lib::TestBuilder;

my $schema = Koha::Database->new->schema;
$schema->storage->txn_begin;

my $builder = t::lib::TestBuilder->new;
my $nb_of_mmts = Koha::MarcModificationTemplates->search->count;
my $new_mmt_1 = Koha::MarcModificationTemplate->new({
    name => 'my_mmt_name_for_test_1',
})->store;
my $new_mmt_2 = Koha::MarcModificationTemplate->new({
    name => 'my_mmt_name_for_test_2',
})->store;

like( $new_mmt_1->template_id, qr|^\d+$|, 'Adding a new mmt should have set the id');
is( Koha::MarcModificationTemplates->search->count, $nb_of_mmts + 2, 'The 2 templates should have been added' );

my $retrieved_mmt_1 = Koha::MarcModificationTemplates->find( $new_mmt_1->template_id );
is( $retrieved_mmt_1->name, $new_mmt_1->name, 'Find a mmt by id should return the correct mmt' );

$retrieved_mmt_1->delete;
is( Koha::MarcModificationTemplates->search->count, $nb_of_mmts + 1, 'Delete should have deleted the mmt' );

$schema->storage->txn_rollback;
