my $maxpickupdelay = C4::Context->preference('ReservesMaxPickUpDelay') || 0; #MaxPickupDelay
$dbh->do(q{ DELETE FROM systempreferences WHERE variable='ReservesMaxPickUpDelay'; });
$dbh->do(q{ DELETE FROM systempreferences WHERE variable='ExpireReservesOnHolidays'; });
#        //DELETE FROM systempreferences WHERE variable='ExpireReservesMaxPickUpDelay'; #This syspref is not needed and would be better suited to be calculated from the holdspickupwait
#        //ExpireReservesMaxPickUpDelayCharge #This could be added as a column to the issuing rules.
$dbh->do(q{ ALTER TABLE issuingrules ADD COLUMN holdspickupwait INT(11) NULL default NULL AFTER reservesallowed; });
$dbh->do(q{ ALTER TABLE reserves ADD COLUMN lastpickupdate DATE NULL default NULL AFTER suspend_until; });
$dbh->do(q{ ALTER TABLE old_reserves ADD COLUMN lastpickupdate DATE NULL default NULL AFTER suspend_until; });
my $sth = $dbh->prepare(q{
    UPDATE issuingrules SET holdspickupwait = ?
});
$sth->execute( $maxpickupdelay ) if $maxpickupdelay; #Don't want to accidentally nullify all!
##Populate the lastpickupdate-column from existing 'ReservesMaxPickUpDelay'
print "Populating the new lastpickupdate-column for all waiting holds. This might take a while.\n";
$sth = $dbh->prepare(q{ SELECT * FROM reserves WHERE found = 'W'; });
$sth->execute( );
my $dtdur = DateTime::Duration->new( days => 0 );
while ( my $res = $sth->fetchrow_hashref ) {
     C4::Reserves::MoveWaitingdate( $res, $dtdur ); #We call MoveWaitingdate with a 0 duration to simply recalculate the lastpickupdate and store the new values to DB.
}
print "Upgrade to $DBversion done (8367: Add colum issuingrules.holdspickupwait and reserves.lastpickupdate. Populates introduced columns from the expiring ReservesMaxPickUpDelay. Deletes the ReservesMaxPickUpDelay and ExpireReservesOnHolidays -sysprefs)\n";>>>>>>> Bug 8367: Template fixes + fixes to C4/Reserves.pm and Koha/Hold.pm
