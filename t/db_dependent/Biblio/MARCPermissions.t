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

use Test::More tests => 16;
use Test::MockModule;

use MARC::Record;
use Data::Dumper;

BEGIN {
    use_ok('C4::Biblio');
}

# Start transaction
my $dbh = C4::Context->dbh;
$dbh->{AutoCommit} = 0;
$dbh->{RaiseError} = 1;

C4::Context->set_preference( 'MARCPermissions', '1');
C4::Context->set_preference( 'MARCPermissionsLog', '1');
C4::Context->set_preference( 'MARCPermissionsCorrectionSimilarity', '90');

# Create a record
my $record = MARC::Record->new();
$record->append_fields (
    MARC::Field->new('008', '12345'),
    MARC::Field->new('100', '','', 'a' => 'field data for 100 a without indicators'),
    MARC::Field->new('250', '','', 'a' => '250 bottles of beer on the wall'),
    MARC::Field->new('245', '1','2', 'a' => 'field data for 245 a with indicators 12'),
    MARC::Field->new('500', '1','1', 'a' => 'the lazy programmer jumps over the quick brown tests'),
    MARC::Field->new('500', '2','2', 'a' => 'the quick brown test jumps over the lazy programmers'),
);

# Add record to DB
my ($biblionumber, $biblioitemnumber) = AddBiblio($record, '');

my $modules = GetMarcPermissionsModules();

##############################################################################
# Test overwrite rule
my $mod_record = MARC::Record->new();
$mod_record->append_fields (
    MARC::Field->new('008', '12345'),
    MARC::Field->new('100', '','', 'a' => 'field data for 100 a without indicators'),
    MARC::Field->new('245', '1','2', 'a' => 'field data for 245 a with indicators 12'),
    MARC::Field->new('500', '1','1', 'a' => 'this field has now been changed'),
    MARC::Field->new('500', '2','2', 'a' => 'and so have this field'),
);

# Clear MARC permission rules from DB
DelMarcPermissionsRule($_->{id}) for GetMarcPermissionsRules();

# Add MARC permission rules to DB
AddMarcPermissionsRule({
    module => $modules->[0]->{'id'},
    tagfield => '*',
    tagsubfield => '',
    filter => '*',
    on_existing => 'overwrite',
    on_new => 'add',
    on_removed => 'remove'
});

my @log = ();
my $new_record = ApplyMarcPermissions({
        biblionumber => $biblionumber,
        record => $mod_record,
        frameworkcode => '',
        filter => {$modules->[0]->{'name'} => 'foo'},
        log => \@log
    });

my @a500 = $new_record->field('500');
is ($a500[0]->subfield('a'), 'this field has now been changed', 'old field is replaced when overwrite');
is ($a500[1]->subfield('a'), 'and so have this field', 'old field is replaced when overwrite');

##############################################################################
# Test remove rule
is ($new_record->field('250'), undef, 'removed field is removed');

##############################################################################
# Test skip rule
$mod_record = MARC::Record->new();
$mod_record->append_fields (
    MARC::Field->new('008', '12345'),
    MARC::Field->new('100', '','', 'a' => 'field data for 100 a without indicators'),
    MARC::Field->new('245', '1','2', 'a' => 'field data for 245 a with indicators 12'),
    MARC::Field->new('500', '1','1', 'a' => 'this should not show'),
    MARC::Field->new('500', '2','2', 'a' => 'and neither should this'),
);

AddMarcPermissionsRule({
    module => $modules->[0]->{'id'},
    tagfield => '500',
    tagsubfield => '*',
    filter => '*',
    on_existing => 'skip',
    on_new => 'skip',
    on_removed => 'skip'
});

@log = ();
$new_record = ApplyMarcPermissions({
        biblionumber => $biblionumber,
        record => $mod_record,
        frameworkcode => '',
        filter => {$modules->[0]->{'name'} => 'foo'},
        log => \@log
    });

@a500 = $new_record->field('500');
is ($a500[0]->subfield('a'), 'the lazy programmer jumps over the quick brown tests', 'old field is kept when skip');
is ($a500[1]->subfield('a'), 'the quick brown test jumps over the lazy programmers', 'old field is kept when skip');

##############################################################################
# Test add rule
$mod_record = MARC::Record->new();
$mod_record->append_fields (
    MARC::Field->new('008', '12345'),
    MARC::Field->new('100', '','', 'a' => 'field data for 100 a without indicators'),
    MARC::Field->new('250', '','', 'a' => '250 bottles of beer on the wall'),
    #MARC::Field->new('245', '1','2', 'a' => 'field data for 245 a with indicators 12'),
    MARC::Field->new('245', '1','2', 'a' => 'some new fun value'),
    MARC::Field->new('500', '1','1', 'a' => 'the lazy programmer jumps over the quick brown tests'),
    MARC::Field->new('500', '2','2', 'a' => 'the quick brown test jumps over the lazy programmers'),
);

AddMarcPermissionsRule({
    module => $modules->[0]->{'id'},
    tagfield => '245',
    tagsubfield => '*',
    filter => '*',
    on_existing => 'add',
    on_new => 'add',
    on_removed => 'skip'
});


@log = ();
$new_record = ApplyMarcPermissions({
        biblionumber => $biblionumber,
        record => $mod_record,
        frameworkcode => '',
        filter => {$modules->[0]->{'name'} => 'foo'},
        log => \@log
    });

my @a245 = $new_record->field('245')->subfield('a');
is ($a245[0], 'field data for 245 a with indicators 12', 'old field is kept when adding new');
is ($a245[1], 'some new fun value', 'new field is added');

##############################################################################
# Test add_or_correct rule
$mod_record = MARC::Record->new();
$mod_record->append_fields (
    MARC::Field->new('008', '12345'),
    #MARC::Field->new('100', '','', 'a' => 'field data for 100 a without indicators'),
    MARC::Field->new('100', '','', 'a' => 'a very different value'),
    MARC::Field->new('250', '','', 'a' => '250 bottles of beer on the wall'),
    #MARC::Field->new('245', '1','2', 'a' => 'field data for 245 a with indicators 12'),
    MARC::Field->new('245', '1','2', 'a' => 'Field data for 245 a with indicators 12', 'a' => 'some very different value'),
    MARC::Field->new('500', '1','1', 'a' => 'the lazy programmer jumps over the quick brown tests'),
    MARC::Field->new('500', '2','2', 'a' => 'the quick brown test jumps over the lazy programmers'),
);

AddMarcPermissionsRule({
    module => $modules->[0]->{'id'},
    tagfield => '(100|245)',
    tagsubfield => '*',
    filter => '*',
    on_existing => 'add_or_correct',
    on_new => 'add',
    on_removed => 'skip'
});

@log = ();
$new_record = ApplyMarcPermissions({
        biblionumber => $biblionumber,
        record => $mod_record,
        frameworkcode => '',
        filter => {$modules->[0]->{'name'} => 'foo'},
        log => \@log
    });

@a245 = $new_record->field('245')->subfield('a');
is ($a245[0], 'Field data for 245 a with indicators 12', 'add_or_correct modifies field when a correction');
is ($a245[1], 'some very different value', 'add_or_correct adds field when not a correction');

my @a100 = $new_record->field('100')->subfield('a');
is ($a100[0], 'field data for 100 a without indicators', 'add_or_correct keeps old field when not a correction');
is ($a100[1], 'a very different value', 'add_or_correct adds field when not a correction');

##############################################################################
# Test rule evaluation order
$mod_record = MARC::Record->new();
$mod_record->append_fields (
    MARC::Field->new('008', '12345'),
    MARC::Field->new('100', '','', 'a' => 'field data for 100 a without indicators'),
    MARC::Field->new('250', '','', 'a' => 'take one down, pass it around'),
    MARC::Field->new('245', '1','2', 'a' => 'field data for 245 a with indicators 12'),
    MARC::Field->new('500', '1','1', 'a' => 'the lazy programmer jumps over the quick brown tests'),
    MARC::Field->new('500', '2','2', 'a' => 'the quick brown test jumps over the lazy programmers'),
);


DelMarcPermissionsRule($_->{id}) for GetMarcPermissionsRules();

AddMarcPermissionsRule({
    module => $modules->[0]->{'id'},
    tagfield => '*',
    tagsubfield => '*',
    filter => '*',
    on_existing => 'skip',
    on_new => 'skip',
    on_removed => 'skip'
});
AddMarcPermissionsRule({
    module => $modules->[0]->{'id'},
    tagfield => '250',
    tagsubfield => '*',
    filter => '*',
    on_existing => 'overwrite',
    on_new => 'skip',
    on_removed => 'skip'
});
AddMarcPermissionsRule({
    module => $modules->[0]->{'id'},
    tagfield => '*',
    tagsubfield => 'a',
    filter => '*',
    on_existing => 'add_or_correct',
    on_new => 'skip',
    on_removed => 'skip'
});
AddMarcPermissionsRule({
    module => $modules->[0]->{'id'},
    tagfield => '250',
    tagsubfield => 'a',
    filter => '*',
    on_existing => 'add',
    on_new => 'skip',
    on_removed => 'skip'
});

@log = ();
$new_record = ApplyMarcPermissions({
        biblionumber => $biblionumber,
        record => $mod_record,
        frameworkcode => '',
        filter => {$modules->[0]->{'name'} => 'foo'},
        log => \@log
    });

my @rule = grep { $_->{tag} eq '250' and $_->{subfieldcode} eq 'a' } @log;
is(scalar @rule, 1, 'only one rule applied');
is($rule[0]->{event}.':'.$rule[0]->{action}, 'existing:add', 'most specific rule used');

my @a250 = $new_record->field('250')->subfield('a');
is ($a250[0], '250 bottles of beer on the wall', 'most specific rule is applied, original field kept');
is ($a250[1], 'take one down, pass it around', 'most specific rule is applied, new field added');

$dbh->rollback;

1;
