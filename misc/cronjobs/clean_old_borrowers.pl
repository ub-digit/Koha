#!/usr/bin/perl

use strict;
use warnings;

use Koha::Script -cron;
use C4::Context;
use Koha::Patrons;

my $dbh = C4::Context->dbh();

my $sql = "SELECT b.borrowernumber
    FROM borrowers b
    LEFT OUTER JOIN issues i ON i.borrowernumber=b.borrowernumber
    LEFT OUTER JOIN reserves r ON r.borrowernumber=b.borrowernumber
    LEFT OUTER JOIN accountlines al 
      ON al.borrowernumber=b.borrowernumber
      AND al.amountoutstanding > 0
    WHERE b.dateexpiry < DATE_SUB(NOW(), INTERVAL 2 YEAR)
    AND  i.borrowernumber IS NULL
    AND  r.borrowernumber IS NULL
    AND al.borrowernumber IS NULL
    AND b.borrowernumber NOT IN (
      SELECT bd.borrowernumber FROM borrower_debarments bd
        WHERE (bd.comment LIKE 'ORI,%' OR bd.comment LIKE 'OR,%')
    )
    ;";

my $res = $dbh->selectall_arrayref($sql, { Slice => {} });

foreach(@$res){
  if ($_->{borrowernumber}){
    my $patron = Koha::Patrons->find($_->{borrowernumber}); 
    $patron->move_to_deleted;
    $patron->delete;
  }
}
