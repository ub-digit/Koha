use utf8;
package Koha::Schema::Result::MarcMergeRule;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::MarcMergeRule

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<marc_merge_rules>

=cut

__PACKAGE__->table("marc_merge_rules");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 tag

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 module

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 0
  size: 255

=head2 filter

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 add

  data_type: 'tinyint'
  is_nullable: 0

=head2 append

  data_type: 'tinyint'
  is_nullable: 0

=head2 remove

  data_type: 'tinyint'
  is_nullable: 0

=head2 delete

  accessor: undef
  data_type: 'tinyint'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "tag",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "module",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 255 },
  "filter",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "add",
  { data_type => "tinyint", is_nullable => 0 },
  "append",
  { data_type => "tinyint", is_nullable => 0 },
  "remove",
  { data_type => "tinyint", is_nullable => 0 },
  "delete",
  { accessor => undef, data_type => "tinyint", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 module

Type: belongs_to

Related object: L<Koha::Schema::Result::MarcMergeRulesModule>

=cut

__PACKAGE__->belongs_to(
  "module",
  "Koha::Schema::Result::MarcMergeRulesModule",
  { name => "module" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2018-06-20 08:56:07
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:CLrTLesHXkGKCs89us0xgQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
