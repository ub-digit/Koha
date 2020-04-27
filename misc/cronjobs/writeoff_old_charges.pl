#!/usr/bin/perl

use strict;
use warnings;

use Koha::Script -cron;
use C4::Context;
use Koha::Patrons;

my $dbh = C4::Context->dbh();

my $sql = "SELECT al.accountlines_id, al.amountoutstanding, al.borrowernumber, al.itemnumber
    FROM accountlines al
    LEFT OUTER JOIN issues i ON (i.borrowernumber=al.borrowernumber AND i.itemnumber=al.itemnumber)
    LEFT OUTER JOIN reserves r ON (r.borrowernumber=al.borrowernumber AND r.itemnumber=al.itemnumber)
    WHERE  al.amountoutstanding>0
      AND  al.date < DATE_SUB(NOW(), INTERVAL 3 YEAR)
      AND  i.borrowernumber IS NULL
      AND  r.borrowernumber IS NULL
    AND al.borrowernumber NOT IN (
      SELECT bd.borrowernumber FROM borrower_debarments bd
        WHERE (bd.comment LIKE 'ORI,%' OR bd.comment LIKE 'OR,%')
    )
    AND al.itemnumber IS NOT NULL
    ;";

my $res = $dbh->selectall_arrayref($sql, { Slice => {} });

foreach(@$res){
  if ($_->{borrowernumber}){
    my $accountlines_id = ($_->{accountlines_id}); 
    my $amount          = ($_->{amountoutstanding});
    my $payment_note    = "Automatic write off, more than 3 years old";
    my $branch          = C4::Context->userenv->{'branch'};    

    Koha::Account->new( { patron_id => ($_->{borrowernumber}) } )->pay(
            {
                amount     => $amount,
                lines      => [ Koha::Account::Lines->find($accountlines_id) ],
                type       => 'WRITEOFF',
                note       => $payment_note,
                interface  => C4::Context->interface,
                library_id => $branch,
            }
        );
  }
}
