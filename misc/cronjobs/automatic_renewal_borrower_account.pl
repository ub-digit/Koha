use strict;
use warnings;

use Koha::Script -cron;
use C4::Context;
use Koha::Patrons;

my $dbh = C4::Context->dbh();

my $sql = "SELECT  b.borrowernumber, b.categorycode, b.dateexpiry, ba.code, ba.attribute
      FROM borrowers b
      JOIN borrower_attributes ba 
      ON ba.borrowernumber = b.borrowernumber 
      WHERE b.categorycode IN ('FA', 'FC', 'FE', 'FH', 'FI', 'FK', 'FL', 'FM', 'FN', 'FS', 'FT', 'FV', 'FY', 'GU', 'PE' ) 
      AND ba.code = 'ANSTSLUT' 
      AND b.dateexpiry < DATE_ADD(CURRENT_DATE, INTERVAL 2 MONTH) 
      AND ba.attribute > CURRENT_DATE";

my $res = $dbh->selectall_arrayref($sql, { Slice => {} });

foreach(@$res){
  if ($_->{borrowernumber}){
    my $renewdate = Koha::Patrons->find($_->{borrowernumber})->renew_account(); 
  }
}
