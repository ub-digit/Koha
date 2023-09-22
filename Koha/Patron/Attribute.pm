package Koha::Patron::Attribute;

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

use Koha::Database;
use Koha::Exceptions::Patron::Attribute;
use Koha::Patron::Attribute::Types;
use Koha::AuthorisedValues;
use Koha::Cache::Memory::Lite;
use C4::Log qw( logaction );
use JSON qw( to_json );

use base qw(Koha::Object);

=head1 NAME

Koha::Patron::Attribute - Koha Patron Attribute Object class

=head1 API

=head2 Class Methods

=cut

=head3 store

    my $attribute = Koha::Patron::Attribute->new({ code => 'a_code', ... });
    try { $attribute->store }
    catch { handle_exception };

=cut

sub store {

    my $self = shift;

    Koha::Exceptions::Patron::Attribute::InvalidType->throw( type => $self->code )
        unless $self->type;

    Koha::Exceptions::Patron::Attribute::NonRepeatable->throw( attribute => $self )
        unless $self->repeatable_ok();

    Koha::Exceptions::Patron::Attribute::UniqueIDConstraint->throw( attribute => $self )
        unless $self->unique_ok();

    # Only log for non-repeatable attributes
    if (!$self->type->repeatable) {
        my $key = "patron_attribute_" . $self->borrowernumber . "_" . $self->code;
        my $cache = Koha::Cache::Memory::Lite->get_instance();
        my $previous_value = $cache->get($key);

        my $change;
        if ( !defined $previous_value ) {
            $change = {
                before => "",
                after  => $self->attribute
            };
        } else {
            if ( $previous_value->{attribute} ne $self->attribute ) {
                $change = {
                    before => $previous_value->{attribute},
                    after  => $self->attribute
                };
            }
        }
        $cache->clear_from_cache($key);
        if (defined $change) {
            logaction( "MEMBERS", "MODIFY", $self->borrowernumber, "Patron attribute " . 
                        $self->code . ": " . to_json($change, { pretty => 1, canonical => 1 }) );
        }
    }

    return $self->SUPER::store();
}

sub delete {
    my ($self) = @_;

    if (!$self->type->repeatable) {
        my $key = "patron_attribute_" . $self->borrowernumber . "_" . $self->code;
        my $cache = Koha::Cache::Memory::Lite->get_instance();
        $cache->set($key, $self->unblessed);
    }

    return $self->SUPER::delete($self);
}

=head3 type

    my $attribute_type = $attribute->type;

Returns a C<Koha::Patron::Attribute::Type> object corresponding to the current patron attribute

=cut

sub type {

    my $self = shift;

    return scalar Koha::Patron::Attribute::Types->find( $self->code );
}

=head3 authorised_value

my $authorised_value = $attribute->authorised_value;

Return the Koha::AuthorisedValue object of this attribute when one is attached.

Return undef if this attribute is not attached to an authorised value

=cut

sub authorised_value {
    my ($self) = @_;

    return unless $self->type->authorised_value_category;

    my $av = Koha::AuthorisedValues->search(
        {
            category         => $self->type->authorised_value_category,
            authorised_value => $self->attribute,
        }
    );
    return unless $av->count; # Data inconsistency
    return $av->next;
}

=head3 description

my $description = $patron_attribute->description;

Return the value of this attribute or the description of the authorised value (when attached).

This method must be called when the authorised value's description must be
displayed instead of the code.

=cut

sub description {
    my ( $self) = @_;
    if ( $self->type->authorised_value_category ) {
        my $av = $self->authorised_value;
        return $av ? $av->lib : "";
    }
    return $self->attribute;
}

=head3 to_api_mapping

This method returns the mapping for representing a Koha::Patron::Attribute object
on the API.

=cut

sub to_api_mapping {
    return {
        id             => 'extended_attribute_id',
        attribute      => 'value',
        borrowernumber => undef,
        code           => 'type'
    };
}

=head3 repeatable_ok

Checks if the attribute type is repeatable and returns a boolean representing
whether storing the current object state would break the repeatable constraint.

=cut

sub repeatable_ok {

    my ( $self ) = @_;

    my $ok = 1;
    if ( ! $self->type->repeatable ) {
        my $params = {
            borrowernumber => $self->borrowernumber,
            code           => $self->code
        };

        $params->{id} = { '!=' => $self->id }
            if $self->in_storage;

        $ok = 0 if Koha::Patron::Attributes->search($params)->count > 0;
    }

    return $ok;
}

=head3 unique_ok

Checks if the attribute type is marked as unique and returns a boolean representing
whether storing the current object state would break the unique constraint.

=cut

sub unique_ok {

    my ( $self ) = @_;

    my $ok = 1;
    if ( $self->type->unique_id ) {
        my $params = { code => $self->code, attribute => $self->attribute };

        $params->{borrowernumber} = { '!=' => $self->borrowernumber } if $self->borrowernumber;
        $params->{id}             = { '!=' => $self->id }             if $self->in_storage;

        my $unique_count = Koha::Patron::Attributes
            ->search( $params )
            ->count;

        $ok = 0 if $unique_count > 0;
    }

    return $ok;
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'BorrowerAttribute';
}

1;
