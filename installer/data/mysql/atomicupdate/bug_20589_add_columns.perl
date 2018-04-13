$DBversion = 'XXX';
if (CheckVersion($DBversion)) {
  if (!column_exists('search_marc_to_field', 'search')) {
    $dbh->do("ALTER TABLE `search_marc_to_field` ADD COLUMN `search` tinyint(1) NOT NULL DEFAULT 1");
  }
  if (!column_exists('search_field', 'staff_client')) {
    $dbh->do("ALTER TABLE `search_field` ADD COLUMN `staff_client` tinyint(1) NOT NULL DEFAULT 1");
  }
  if (!column_exists('search_field', 'opac')) {
    $dbh->do("ALTER TABLE `search_field` ADD COLUMN `opac` tinyint(1) NOT NULL DEFAULT 1");
  }
  SetVersion($DBversion)
}
print "Upgrade to $DBversion done (Bug 20589 - Add field boosting and use elastic query fields parameter instead of depricated _all)\n";
