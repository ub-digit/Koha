#!/usr/bin/perl

# Copyright 2012 Mark Gavillet & PTFS Europe Ltd
#
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

# This is an awkward construct and should probably be totally replaced
# but as all sites so far are single ordering ean its not clear what we should
# replace it with
#
use Modern::Perl;

use C4::Auth qw( get_template_and_user );
use C4::Output qw( output_html_with_http_headers );
use Koha::Database;
use CGI;
my $schema = Koha::Database->new()->schema();
my $query    = CGI->new(); 

#GU - Get bookseller id and set search filter term
my $bookseller_id = $query->param('booksellerid');
my @booksellers = (" Adlib ", " Daw ", " Delb ", "", " Bokus ", " Ebsco ", " Jure ");
my $bookseller =  $booksellers[$bookseller_id-1];

my @eans = $schema->resultset('EdifactEan')->search(
    {},
    {
        where => { description => { 'LIKE', '%' . $bookseller . '%' }}, #GU - Filter on booksellerid
        join => 'branch',
        order_by => { -asc => 'branchname' }, #GU - Sort alphabetically
    }
);
my $basketno = $query->param('basketno');

if ( @eans == 1 ) {
    my $ean = $eans[0]->ean;
    print $query->redirect(
        "/cgi-bin/koha/acqui/basket.pl?basketno=$basketno&op=ediorder&ean=$ean"
    );
}
else {
    my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
        {
            template_name   => 'acqui/edi_ean.tt',
            query           => $query,
            type            => 'intranet',
            flagsrequired   => { acquisition => 'order_manage' },
        }
    );
    $template->param( eans     => \@eans );
    $template->param( basketno => $basketno );

    output_html_with_http_headers( $query, $cookie, $template->output );
}
