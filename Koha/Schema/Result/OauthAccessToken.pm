use utf8;
package Koha::Schema::Result::OauthAccessToken;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::OauthAccessToken

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<oauth_access_tokens>

=cut

__PACKAGE__->table("oauth_access_tokens");

=head1 ACCESSORS

=head2 access_token

  data_type: 'varchar'
  is_nullable: 0
  size: 191

=head2 client_id

  data_type: 'varchar'
  is_nullable: 0
  size: 191

=head2 expires

  data_type: 'integer'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "access_token",
  { data_type => "varchar", is_nullable => 0, size => 191 },
  "client_id",
  { data_type => "varchar", is_nullable => 0, size => 191 },
  "expires",
  { data_type => "integer", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</access_token>

=back

=cut

__PACKAGE__->set_primary_key("access_token");


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2018-05-09 12:50:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:M6tueO6jmJwgmwMrqO1L0Q

sub koha_object_class {
    'Koha::OAuthAccessToken';
}
sub koha_objects_class {
    'Koha::OAuthAccessTokens';
}

1;
