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
use Try::Tiny;

use MARC::Record;

use C4::Context;
use C4::Biblio;
use Koha::Database; #??

use Test::More tests => 22;
use Test::MockModule;

use Koha::MarcMergeRules;
use Koha::MarcMergeRulesModules;

use t::lib::Mocks;

my $schema = Koha::Database->schema;
$schema->storage->txn_begin;

t::lib::Mocks::mock_preference('MARCMergeRules', '1');

# Create a record
my $orig_record = MARC::Record->new();
$orig_record->append_fields (
    MARC::Field->new('250', '','', 'a' => '250 bottles of beer on the wall'),
    MARC::Field->new('250', '','', 'a' => '256 bottles of beer on the wall'),
    MARC::Field->new('500', '','', 'a' => 'One bottle of beer in the fridge'),
);

my $modules_rs = Koha::MarcMergeRulesModules->search(undef, { order_by => { -desc => 'specificity' } });
my @modules;
push @modules, $modules_rs->next;

my $incoming_record = MARC::Record->new();
$incoming_record->append_fields(
    MARC::Field->new('250', '', '', 'a' => '256 bottles of beer on the wall'), # Unchanged
    MARC::Field->new('250', '', '', 'a' => '251 bottles of beer on the wall'), # Appended
    # MARC::Field->new('250', '', '', 'a' => '250 bottles of beer on the wall'), # Removed
    # MARC::Field->new('500', '', '', 'a' => 'One bottle of beer in the fridge'), # Deleted
    MARC::Field->new('501', '', '', 'a' => 'One cold bottle of beer in the fridge'), # Added
    MARC::Field->new('501', '', '', 'a' => 'Two cold bottles of beer in the fridge'), # Added
);

# Test default behavior when MARCMergeRules is enabled, but no rules defined (overwrite)
subtest 'Record fields has been overwritten when no merge rules are defined' => sub {
    plan tests => 4;

    my $merged_record = Koha::MarcMergeRules->merge_records($orig_record, $incoming_record, { $modules[0]->name => 'test' });

    my @all_fields = $merged_record->fields();

    cmp_ok(scalar @all_fields, '==', 4, "Record has the expected number of fields");
    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('250') ],
        ['256 bottles of beer on the wall', '251 bottles of beer on the wall'],
        '"250" fields has been appended and removed'
    );

    my @fields = $merged_record->field('500');
    cmp_ok(scalar @fields, '==', 0, '"500" field has been deleted');

    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('501') ],
        ['One cold bottle of beer in the fridge', 'Two cold bottles of beer in the fridge'],
        '"501" fields has been added'
    );
};

my $rule =  Koha::MarcMergeRules->find_or_create({
    tag => '*',
    module => $modules[0]->id,
    filter => '*',
    add => 0,
    append => 0,
    remove => 0,
    delete => 0
});

subtest 'Record fields has been protected when matched merge all rule operations are set to "0"' => sub {
    plan tests => 3;

    my $merged_record = Koha::MarcMergeRules->merge_records($orig_record, $incoming_record, { $modules[0]->name => 'test' });

    my @all_fields = $merged_record->fields();
    cmp_ok(scalar @all_fields, '==', 3, "Record has the expected number of fields");

    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('250') ],
        ['250 bottles of beer on the wall', '256 bottles of beer on the wall'],
        '"250" fields has retained their original value'
    );
    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('500') ],
        ['One bottle of beer in the fridge'],
        '"500" field has retained it\'s original value'
    );
};

subtest 'Only new fields has been added when add = 1, append = 0, remove = 0, delete = 0' => sub {
    plan tests => 4;

    $rule->set(
        {
            'add' => 1,
            'append' => 0,
            'remove' => 0,
            'delete' => 0,
        }
    );
    $rule->store();

    my $merged_record = Koha::MarcMergeRules->merge_records($orig_record, $incoming_record, { $modules[0]->name => 'test' });

    my @all_fields = $merged_record->fields();
    cmp_ok(scalar @all_fields, '==', 5, "Record has the expected number of fields");

    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('250') ],
        ['250 bottles of beer on the wall', '256 bottles of beer on the wall'],
        '"250" fields retain their original value'
    );

    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('500') ],
        ['One bottle of beer in the fridge'],
        '"500" field retain it\'s original value'
    );

    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('501') ],
        ['One cold bottle of beer in the fridge', 'Two cold bottles of beer in the fridge'],
        '"501" fields has been added'
    );
};

subtest 'Only appended fields has been added when add = 0, append = 1, remove = 0, delete = 0' => sub {
    plan tests => 3;

    $rule->set(
        {
            'add' => 0,
            'append' => 1,
            'remove' => 0,
            'delete' => 0,
        }
    );
    $rule->store();

    my $merged_record = Koha::MarcMergeRules->merge_records($orig_record, $incoming_record, { $modules[0]->name => 'test' });

    my @all_fields = $merged_record->fields();
    cmp_ok(scalar @all_fields, '==', 4, "Record has the expected number of fields");

    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('250') ],
        ['250 bottles of beer on the wall', '256 bottles of beer on the wall', '251 bottles of beer on the wall'],
        '"251" field has been appended'
    );

    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('500') ],
        ['One bottle of beer in the fridge'],
        '"500" field has retained it\'s original value'
    );

};

subtest 'Appended and added fields has been added when add = 1, append = 1, remove = 0, delete = 0' => sub {
    plan tests => 4;

    $rule->set(
        {
            'add' => 1,
            'append' => 1,
            'remove' => 0,
            'delete' => 0,
        }
    );
    $rule->store();

    my $merged_record = Koha::MarcMergeRules->merge_records($orig_record, $incoming_record, { $modules[0]->name => 'test' });

    my @all_fields = $merged_record->fields();
    cmp_ok(scalar @all_fields, '==', 6, "Record has the expected number of fields");

    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('250') ],
        ['250 bottles of beer on the wall', '256 bottles of beer on the wall', '251 bottles of beer on the wall'],
        '"251" field has been appended'
    );

    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('500') ],
        ['One bottle of beer in the fridge'],
        '"500" field has retained it\'s original value'
    );

    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('501') ],
        ['One cold bottle of beer in the fridge', 'Two cold bottles of beer in the fridge'],
        '"501" fields has been added'
    );
};

subtest 'Record fields has been only removed when add = 0, append = 0, remove = 1, delete = 0' => sub {
    plan tests => 3;

    $rule->set(
        {
            'add' => 0,
            'append' => 0,
            'remove' => 1,
            'delete' => 0,
        }
    );
    $rule->store();

    my $merged_record = Koha::MarcMergeRules->merge_records($orig_record, $incoming_record, { $modules[0]->name => 'test' });

    my @all_fields = $merged_record->fields();
    cmp_ok(scalar @all_fields, '==', 2, "Record has the expected number of fields");

    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('250') ],
        ['256 bottles of beer on the wall'],
        '"250" field has been removed'
    );
    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('500') ],
        ['One bottle of beer in the fridge'],
        '"500" field has retained it\'s original value'
    );
};

subtest 'Record fields has been added and removed when add = 1, append = 0, remove = 1, delete = 0' => sub {
    plan tests => 4;

    $rule->set(
        {
            'add' => 1,
            'append' => 0,
            'remove' => 1,
            'delete' => 0,
        }
    );
    $rule->store();

    my $merged_record = Koha::MarcMergeRules->merge_records($orig_record, $incoming_record, { $modules[0]->name => 'test' });

    my @all_fields = $merged_record->fields();
    cmp_ok(scalar @all_fields, '==', 4, "Record has the expected number of fields");

    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('250') ],
        ['256 bottles of beer on the wall'],
        '"250" field has been removed'
    );
    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('500') ],
        ['One bottle of beer in the fridge'],
        '"500" field has retained it\'s original value'
    );

    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('501') ],
        ['One cold bottle of beer in the fridge', 'Two cold bottles of beer in the fridge'],
        '"501" fields has been added'
    );
};

subtest 'Record fields has been appended and removed when add = 0, append = 1, remove = 1, delete = 0' => sub {
    plan tests => 3;

    $rule->set(
        {
            'add' => 0,
            'append' => 1,
            'remove' => 1,
            'delete' => 0,
        }
    );
    $rule->store();

    my $merged_record = Koha::MarcMergeRules->merge_records($orig_record, $incoming_record, { $modules[0]->name => 'test' });

    my @all_fields = $merged_record->fields();
    cmp_ok(scalar @all_fields, '==', 3, "Record has the expected number of fields");

    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('250') ],
        ['256 bottles of beer on the wall', '251 bottles of beer on the wall'],
        '"250" fields has been appended and removed'
    );
    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('500') ],
        ['One bottle of beer in the fridge'],
        '"500" field has retained it\'s original value'
    );
};

subtest 'Record fields has been added, appended and removed when add = 0, append = 1, remove = 1, delete = 0' => sub {
    plan tests => 4;

    $rule->set(
        {
            'add' => 1,
            'append' => 1,
            'remove' => 1,
            'delete' => 0,
        }
    );
    $rule->store();

    my $merged_record = Koha::MarcMergeRules->merge_records($orig_record, $incoming_record, { $modules[0]->name => 'test' });

    my @all_fields = $merged_record->fields();
    cmp_ok(scalar @all_fields, '==', 5, "Record has the expected number of fields");

    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('250') ],
        ['256 bottles of beer on the wall', '251 bottles of beer on the wall'],
        '"250" fields has been appended and removed'
    );

    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('500') ],
        ['One bottle of beer in the fridge'],
        '"500" field has retained it\'s original value'
    );

    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('501') ],
        ['One cold bottle of beer in the fridge', 'Two cold bottles of beer in the fridge'],
        '"501" fields has been added'
    );
};

subtest 'Record fields has been deleted when add = 0, append = 0, remove = 0, delete = 1' => sub {
    plan tests => 2;

    $rule->set(
        {
            'add' => 0,
            'append' => 0,
            'remove' => 0,
            'delete' => 1,
        }
    );
    $rule->store();

    my $merged_record = Koha::MarcMergeRules->merge_records($orig_record, $incoming_record, { $modules[0]->name => 'test' });

    my @all_fields = $merged_record->fields();
    cmp_ok(scalar @all_fields, '==', 2, "Record has the expected number of fields");

    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('250') ],
        ['250 bottles of beer on the wall', '256 bottles of beer on the wall'],
        '"250" fields has retained their original value'
    );
};

subtest 'Record fields has been added and deleted when add = 1, append = 0, remove = 0, delete = 1' => sub {
    plan tests => 3;

    $rule->set(
        {
            'add' => 1,
            'append' => 0,
            'remove' => 0,
            'delete' => 1,
        }
    );
    $rule->store();

    my $merged_record = Koha::MarcMergeRules->merge_records($orig_record, $incoming_record, { $modules[0]->name => 'test' });

    my @all_fields = $merged_record->fields();
    cmp_ok(scalar @all_fields, '==', 4, "Record has the expected number of fields");

    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('250') ],
        ['250 bottles of beer on the wall', '256 bottles of beer on the wall'],
        '"250" fields has retained their original value'
    );

    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('501') ],
        ['One cold bottle of beer in the fridge', 'Two cold bottles of beer in the fridge'],
        '"501" fields has been added'
    );
};

subtest 'Record fields has been appended and deleted when add = 0, append = 1, remove = 0, delete = 1' => sub {
    plan tests => 2;

    $rule->set(
        {
            'add' => 0,
            'append' => 1,
            'remove' => 0,
            'delete' => 1,
        }
    );
    $rule->store();

    my $merged_record = Koha::MarcMergeRules->merge_records($orig_record, $incoming_record, { $modules[0]->name => 'test' });

    my @all_fields = $merged_record->fields();
    cmp_ok(scalar @all_fields, '==', 3, "Record has the expected number of fields");

    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('250') ],
        ['250 bottles of beer on the wall', '256 bottles of beer on the wall', '251 bottles of beer on the wall'],
        '"250" field has been appended'
    );
};

subtest 'Record fields has been added, appended and deleted when add = 1, append = 1, remove = 0, delete = 1' => sub {
    plan tests => 3;

    $rule->set(
        {
            'add' => 1,
            'append' => 1,
            'remove' => 0,
            'delete' => 1,
        }
    );
    $rule->store();

    my $merged_record = Koha::MarcMergeRules->merge_records($orig_record, $incoming_record, { $modules[0]->name => 'test' });

    my @all_fields = $merged_record->fields();
    cmp_ok(scalar @all_fields, '==', 5, "Record has the expected number of fields");

    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('250') ],
        ['250 bottles of beer on the wall', '256 bottles of beer on the wall', '251 bottles of beer on the wall'],
        '"250" field has been appended'
    );

    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('501') ],
        ['One cold bottle of beer in the fridge', 'Two cold bottles of beer in the fridge'],
        '"501" fields has been added'
    );
};

subtest 'Record fields has been removed and deleted when add = 0, append = 0, remove = 1, delete = 1' => sub {
    plan tests => 2;

    $rule->set(
        {
            'add' => 0,
            'append' => 0,
            'remove' => 1,
            'delete' => 1,
        }
    );
    $rule->store();

    my $merged_record = Koha::MarcMergeRules->merge_records($orig_record, $incoming_record, { $modules[0]->name => 'test' });

    my @all_fields = $merged_record->fields();
    cmp_ok(scalar @all_fields, '==', 1, "Record has the expected number of fields");

    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('250') ],
        ['256 bottles of beer on the wall'],
        '"250" field has been removed'
    );
};

subtest 'Record fields has been added, removed and deleted when add = 1, append = 0, remove = 1, delete = 1' => sub {
    plan tests => 3;

    $rule->set(
        {
            'add' => 1,
            'append' => 0,
            'remove' => 1,
            'delete' => 1,
        }
    );
    $rule->store();

    my $merged_record = Koha::MarcMergeRules->merge_records($orig_record, $incoming_record, { $modules[0]->name => 'test' });

    my @all_fields = $merged_record->fields();
    cmp_ok(scalar @all_fields, '==', 3, "Record has the expected number of fields");

    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('250') ],
        ['256 bottles of beer on the wall'],
        '"250" field has been removed'
    );

    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('501') ],
        ['One cold bottle of beer in the fridge', 'Two cold bottles of beer in the fridge'],
        '"501" fields has been added'
    );
};

subtest 'Record fields has been appended, removed and deleted when add = 0, append = 1, remove = 1, delete = 1' => sub {
    plan tests => 2;

    $rule->set(
        {
            'add' => 0,
            'append' => 1,
            'remove' => 1,
            'delete' => 1,
        }
    );
    $rule->store();

    my $merged_record = Koha::MarcMergeRules->merge_records($orig_record, $incoming_record, { $modules[0]->name => 'test' });

    my @all_fields = $merged_record->fields();
    cmp_ok(scalar @all_fields, '==', 2, "Record has the expected number of fields");

    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('250') ],
        ['256 bottles of beer on the wall', '251 bottles of beer on the wall'],
        '"250" fields has been appended and removed'
    );
};

subtest 'Record fields has been overwritten when add = 1, append = 1, remove = 1, delete = 1' => sub {
    plan tests => 4;

    $rule->set(
        {
            'add' => 1,
            'append' => 1,
            'remove' => 1,
            'delete' => 1,
        }
    );
    $rule->store();

    my $merged_record = Koha::MarcMergeRules->merge_records($orig_record, $incoming_record, { $modules[0]->name => 'test' });

    my @all_fields = $merged_record->fields();

    cmp_ok(scalar @all_fields, '==', 4, "Record has the expected number of fields");
    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('250') ],
        ['256 bottles of beer on the wall', '251 bottles of beer on the wall'],
        '"250" fields has been appended and removed'
    );

    my @fields = $merged_record->field('500');
    cmp_ok(scalar @fields, '==', 0, '"500" field has been deleted');

    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('501') ],
        ['One cold bottle of beer in the fridge', 'Two cold bottles of beer in the fridge'],
        '"501" fields has been added'
    );
};

# Test rule tag specificity

# Protect field 500 with more specific tag value
my $skip_all_rule = Koha::MarcMergeRules->find_or_create({
    tag => '500',
    module => $modules[0]->id,
    filter => '*',
    add => 0,
    append => 0,
    remove => 0,
    delete => 0
});

subtest '"500" field has been protected when rule matching on tag "500" is add = 0, append = 0, remove = 0, delete = 0' => sub {
    plan tests => 4;

    my $merged_record = Koha::MarcMergeRules->merge_records($orig_record, $incoming_record, { $modules[0]->name => 'test' });

    my @all_fields = $merged_record->fields();

    cmp_ok(scalar @all_fields, '==', 5, "Record has the expected number of fields");
    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('250') ],
        ['256 bottles of beer on the wall', '251 bottles of beer on the wall'],
        '"250" fields has been appended and removed'
    );

    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('500') ],
        ['One bottle of beer in the fridge'],
        '"500" field has retained it\'s original value'
    );

    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('501') ],
        ['One cold bottle of beer in the fridge', 'Two cold bottles of beer in the fridge'],
        '"501" fields has been added'
    );
};

# Test regexp matching
subtest '"5XX" fields has been protected when rule matching on regexp "5\d{2}" is add = 0, append = 0, remove = 0, delete = 0' => sub {
    plan tests => 3;

    $skip_all_rule->set(
        {
            'tag' => '5\d{2}',
        }
    );
    $skip_all_rule->store();

    my $merged_record = Koha::MarcMergeRules->merge_records($orig_record, $incoming_record, { $modules[0]->name => 'test' });

    my @all_fields = $merged_record->fields();

    cmp_ok(scalar @all_fields, '==', 3, "Record has the expected number of fields");
    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('250') ],
        ['256 bottles of beer on the wall', '251 bottles of beer on the wall'],
        '"250" fields has been appended and removed'
    );

    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('500') ],
        ['One bottle of beer in the fridge'],
        '"500" field has retained it\'s original value'
    );
};

# Test module specificity, the 0 all rule should no longer be included in set of applied rules
subtest 'Record fields has been overwritten when non wild card rule with filter match is add = 1, append = 1, remove = 1, delete = 1' => sub {
    plan tests => 4;

    $rule->set(
        {
            'filter' => 'test',
        }
    );
    $rule->store();

    my $merged_record = Koha::MarcMergeRules->merge_records($orig_record, $incoming_record, { $modules[0]->name => 'test' });

    my @all_fields = $merged_record->fields();

    cmp_ok(scalar @all_fields, '==', 4, "Record has the expected number of fields");
    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('250') ],
        ['256 bottles of beer on the wall', '251 bottles of beer on the wall'],
        '"250" fields has been appended and removed'
    );

    my @fields = $merged_record->field('500');
    cmp_ok(scalar @fields, '==', 0, '"500" field has been deleted');

    is_deeply(
        [map { $_->subfield('a') } $merged_record->field('501') ],
        ['One cold bottle of beer in the fridge', 'Two cold bottles of beer in the fridge'],
        '"501" fields has been added'
    );
};

subtest 'An exception is thrown when append = 1, remove = 0 is set for control field rule' => sub {
    plan tests => 2;
    my $exception = try {
        Koha::MarcMergeRules->validate({
            'tag' => '008',
            'append' => 1,
            'remove' => 0,
        });
    }
    catch {
        return $_;
    };
    ok(defined $exception, "Exception was caught");
    ok($exception->isa('Koha::Exceptions::MarcMergeRule::InvalidControlFieldActions'), "Exception is of correct class");
};

subtest 'An exception is thrown when rule tag is set to invalid regexp' => sub {
    plan tests => 2;

    my $exception = try {
        Koha::MarcMergeRules->validate({
            'tag' => '**'
        });
    }
    catch {
        return $_;
    };
    ok(defined $exception, "Exception was caught");
    ok($exception->isa('Koha::Exceptions::MarcMergeRule::InvalidTagRegExp'), "Exception is of correct class");
};

$schema->storage->txn_rollback;

1;
