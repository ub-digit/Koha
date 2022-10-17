#!/usr/bin/perl

# This file is part of Koha.
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

use Test::More tests => 5;
use Test::MockModule;
use Test::Warn;
use t::lib::Mocks;
use t::lib::TestBuilder;

use File::Basename;

use MARC::Record;

use Koha::Database;
use Koha::Biblios;

BEGIN {
    # Mock pluginsdir before loading Plugins module
    my $path = dirname(__FILE__) . '/../../../lib/plugins';
    t::lib::Mocks::mock_config( 'pluginsdir', $path );

    use_ok('Koha::Plugins');
    use_ok('Koha::Plugins::Handler');
    use_ok('Koha::Plugin::Test');
}

my $schema = Koha::Database->schema();

use_ok('Koha::SearchEngine::Elasticsearch::Indexer');

SKIP: {

    eval { Koha::SearchEngine::Elasticsearch->get_elasticsearch_params; };

    skip 'Elasticsearch configuration not available', 2
        if $@;

my $builder = t::lib::TestBuilder->new;
my $biblio = $builder->build_sample_biblio; # create biblio before we start mocking to avoid trouble indexing on creation
t::lib::Mocks::mock_config( 'enable_plugins', 1 );

subtest 'before_index_action hook' => sub {
    plan tests => 1;

    $schema->storage->txn_begin;
    my $plugins = Koha::Plugins->new;
    $plugins->InstallPlugins;

    my $plugin = Koha::Plugin::Test->new->enable;
    my $test_plugin = Test::MockModule->new('Koha::Plugin::Test');
    $test_plugin->mock( 'after_biblio_action', undef );

    my $biblio = $builder->build_sample_biblio;
    my $biblionumber = $biblio->biblionumber;

    my $indexer = Koha::SearchEngine::Elasticsearch::Indexer->new({ 'index' => 'biblios' });
    warning_like {
        $indexer->update_index([$biblionumber]);
    }
    qr/before_index_action called with action: update, engine: Elasticsearch, ref: ARRAY/,
    '-> update_index calls the before_index_action hook';

    $schema->storage->txn_rollback;
    Koha::Plugins::Methods->delete;
};

}
