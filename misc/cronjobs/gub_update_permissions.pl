#!/usr/bin/perl

use Modern::Perl;

use CGI qw ( -utf8 );
use C4::Output;
use C4::Auth qw(:DEFAULT :EditPermissions);
use C4::Context;
use C4::Members;
use Koha::Patron::Categories;
use Koha::Patrons;
use Koha::Token;

use Koha::Script -cron;
use Data::Dumper; 

my $dbh = C4::Context->dbh();

my $specific_borrowernumber = "$ARGV[0]";

### Mallposterna med flaggor

my $sql = "select borrowernumber, cardnumber, flags 
		   from borrowers 
		   where cardnumber LIKE 'PERM_%'
		   ;";
		   
my $res = $dbh->selectall_arrayref($sql, { Slice => {} });

### Personalposter

my $sql2;
my $staff;

if($specific_borrowernumber) {
  $sql2 = "select b.borrowernumber, GROUP_CONCAT(ba.code SEPARATOR ', ') AS bor_attributes
		   from borrowers b
		   JOIN borrower_attributes ba 
		   ON (b.borrowernumber = ba.borrowernumber AND ba.code LIKE 'PERM_%')
		   where (b.userid != 'admin' OR b.flags is null)
                   AND b.borrowernumber = ?
		   group by 1
		   ;";
  $staff = $dbh->selectall_arrayref($sql2, { Slice => {} }, $specific_borrowernumber);


} else {
  $sql2 = "select b.borrowernumber, GROUP_CONCAT(ba.code SEPARATOR ', ') AS bor_attributes
		   from borrowers b
		   JOIN borrower_attributes ba 
		   ON (b.borrowernumber = ba.borrowernumber AND ba.code LIKE 'PERM_%')
		   where (b.userid != 'admin' OR b.flags is null)
		   group by 1
		   ;";
  $staff = $dbh->selectall_arrayref($sql2, { Slice => {} });
}


### Uppdatera flags 

my $sth = $dbh-> prepare("UPDATE borrowers SET flags=? WHERE borrowernumber=?");

my $new_flags = 0;

foreach my $st(@$staff){
	my $bnr = $st->{borrowernumber};
	$new_flags = 0;
	my @temp = split(/, /, $st->{bor_attributes});
	### check if borrower_attribute PERM_SUP exists
	if ( grep( /PERM_SUP/, @temp ) ) {
		### Super librarian - set flags to 1
		$new_flags = 1;
	}else{
		foreach my $t(@temp) {
			foreach my $p (@$res){
				if ($t eq $p->{cardnumber}){
					$new_flags |= $p->{flags};
				}
									
			}
		}
	}
	$sth->execute($new_flags, $bnr);
}

### User_permissions mallposter

my $sql3 =( "SELECT b.cardnumber, flag, 
				up.code
				FROM user_permissions up
				JOIN permissions USING (module_bit, code)
				JOIN userflags ON (module_bit = bit)
				JOIN borrowers b ON b.borrowernumber = up.borrowernumber
				WHERE b.cardnumber LIKE 'PERM_%'
				;");
			 


my $perms = $dbh->selectall_arrayref($sql3);

### Bygg hash för mallposternas sub_permissions

my %sub_perms = ();
foreach my$perm(@$perms){
	my $card = $perm->[0];
	my $module = $perm->[1]; 
	my $sub_perm = $perm->[2];

	push @{$sub_perms{$card}{$module}}, $sub_perm;
}


### Uppdatera user_permissions


foreach my $st (@$staff){
	my $bnr = $st->{borrowernumber};
	$sth = $dbh->prepare("DELETE FROM user_permissions WHERE borrowernumber = ?");
    $sth->execute($bnr); 
	my @temp = split(/, /, $st->{bor_attributes});
	### check if borrower_attribute PERM_SUP exists and if so, omit setting user permissions 
	if (!grep( /PERM_SUP/, @temp ) ) {
		foreach my $t(@temp) {
			foreach my $temp_group (keys %sub_perms) {
				if ($t eq $temp_group){
					$sth = $dbh->prepare("
	                        INSERT INTO user_permissions (borrowernumber, module_bit, code)
	                        SELECT ?, bit, ?
	                        FROM userflags uf
	                        WHERE flag = ?
	                        AND NOT EXISTS (SELECT * from user_permissions up where up.borrowernumber = ?
	                                        AND up.module_bit = uf.bit AND up.code = ?)");
					foreach my $module(%{$sub_perms{$temp_group}} ) {
						foreach my $sub_perm(@{$sub_perms{$temp_group}{$module}} ) {
							$sth->execute($bnr, $sub_perm, $module, $bnr, $sub_perm);
						}
					}
				}
			}
		}
	}	
}