use utf8;
package Koha::Schema::Result::MarcMergeRulesModule;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::MarcMergeRulesModule

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<marc_merge_rules_modules>

=cut

__PACKAGE__->table("marc_merge_rules_modules");

=head1 ACCESSORS

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 description

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 specificity

  data_type: 'integer'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "description",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "specificity",
  { data_type => "integer", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->set_primary_key("name");

=head1 UNIQUE CONSTRAINTS

=head2 C<specificity>

=over 4

=item * L</specificity>

=back

=cut

__PACKAGE__->add_unique_constraint("specificity", ["specificity"]);

=head1 RELATIONS

=head2 marc_merge_rules

Type: has_many

Related object: L<Koha::Schema::Result::MarcMergeRule>

=cut

__PACKAGE__->has_many(
  "marc_merge_rules",
  "Koha::Schema::Result::MarcMergeRule",
  { "foreign.module" => "self.name" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2018-06-15 12:11:59
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:bNG+m3wj6NDa6mZCtI2nKg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
