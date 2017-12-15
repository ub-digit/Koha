package Koha::Items;

# Copyright ByWater Solutions 2014
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;

use Carp;

use Koha::Database;

use Koha::Item;

use base qw(Koha::Objects);

=head1 NAME

Koha::Items - Koha Item object set class

=head1 API

=head2 Class Methods

=cut

=head3 type

=cut

sub _type {
    return 'Item';
}

=head3 object_class

=cut

sub object_class {
    return 'Koha::Item';
}

=head2 search_unblessed

    $items = Koha::Items->search_unblessed($conditions);

In scalar context, returns an array reference with hashes containing item data, in list context returns an array.
Calling search_unblessed should produce the same result as calling Koha::Items->search and iterating
though the result unblessing each item. In cases where you only need the item data using this optimized
method is much faster. The arguments accepted are a subset and approximation of those supported by
Koha::items->search, with only the "barcode" and "itemnumber" attributes supported as conditions.
If called with a non-hash conditions argument a search will be performed as if "itemnumber" was the
provided condition. Only one condition is accepted and if more are provided the method will die with
an error.

=cut

sub search_unblessed {
    my ($self, $conditions) = @_;
    my $items = [];
    my $field_name;
    if (ref($conditions) eq 'HASH') {
        my %valid_condition_fields = (
            'barcode' => undef,
            'itemnumber' => undef,
        );
        my @fields = keys %{$conditions};
        if (@fields == 1) {
            foreach my $field (@fields) {
                die("Invalid condition: \"$field\"") unless exists $valid_condition_fields{$field};
            }
        }
        elsif(@fields > 1) {
            die("Multiple conditions are not supported");
        }
        else {
            die("No conditions provided");
        }
    }
    else {
        $conditions = {
            'itemnumber' => $conditions,
        };
    }
    # Only accepts one condition
    my ($field, $values) = (%{$conditions});

    if (ref($values) eq 'ARRAY' && @{$values} == 1) {
        ($values) = @{$values};
    }
    if (!ref($values)) {
        my $item = C4::Context->dbh->selectrow_hashref(qq{SELECT * FROM items WHERE $field = ?}, undef, $values);
        push @{$items}, $item;
    }
    elsif (ref($values) eq 'ARRAY') {
        my $in = join ', ', (('?') x @{$values});
        my $sth = C4::Context->dbh->prepare(qq{SELECT * FROM items WHERE $field IN($in)});
        $sth->execute(@{$values});
        while (my $item = $sth->fetchrow_hashref) {
            push @{$items}, $item;
        }
    }
    else {
        die("Invalid value for field: \"$field\"");
    }
    return wantarray ? @{$items} : $items;
}

=head1 AUTHOR

Kyle M Hall <kyle@bywatersolutions.com>

=cut

1;
