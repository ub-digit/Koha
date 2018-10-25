package Koha::MarcMergeRule;

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
use Koha::Exceptions::MarcMergeRule;
use Try::Tiny;

use parent qw(Koha::Object);

my $cache = Koha::Caches->get_instance();

=head1 NAME

Koha::MarcMergeRule - Koha SearchField Object class

=cut

sub set {
    my $self = shift @_;
    my ($rule_data) =  @_;

    if ($rule_data->{tag} ne '*') {
        eval { qr/$rule_data->{tag}/ };
        if ($@) {
            Koha::Exceptions::MarcMergeRule::InvalidTagRegExp->throw(
                "Invalid tag regular expression"
            );
        }
    }
    if (
        $rule_data->{tag} < 10 &&
        $rule_data->{append} &&
        !$rule_data->{remove}
    ) {
        Koha::Exceptions::MarcMergeRule::InvalidControlFieldActions->throw(
            "Combination of allow append and skip remove not permitted for control fields"
        );
    }

    $self->SUPER::set(@_);
}

sub store {
    my $self = shift @_;
    $cache->clear_from_cache('marc_merge_rules');
    $self->SUPER::store(@_);
}

sub _type {
    return 'MarcMergeRule';
}

1;
