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

sub search_unblessed {
    my ($self, $conditions) = @_;
    my $items = [];
    my $field_name;
    if (ref($conditions) eq 'HASH') {
        my %valid_condition_fields = (
            'barcode' => undef,
            'itemnumber' => undef,
        );
        foreach my $field (keys %{$conditions}) {
            die ("Invalid condition: \"$field\"") unless exists $valid_condition_fields{$field};
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
        die("Invalid $field value");
    }
    return $items;
}

=head1 AUTHOR

Kyle M Hall <kyle@bywatersolutions.com>

=cut

1;
