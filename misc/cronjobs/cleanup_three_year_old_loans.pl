#!/usr/bin/perl

use strict;
use warnings;

use Koha::Script -cron;
use C4::Context;
use Koha::Patrons;
use Modern::Perl;
use Koha::Items;

my $dbh = C4::Context->dbh();

my $sql = "SELECT i.issue_id, i.itemnumber, i.branchcode, i.date_due, it.itype, it.permanent_location, it.biblionumber, bi.title, bi.author, it.itemcallnumber, bo.categorycode, i.auto_renew,i.note
	FROM issues i
	LEFT JOIN items it ON it.itemnumber=i.itemnumber
	LEFT JOIN biblio bi ON bi.biblionumber=it.biblionumber
	LEFT JOIN borrowers bo ON bo.borrowernumber=i.borrowernumber
 	WHERE i.date_due < DATE_SUB(NOW(), INTERVAL 3 YEAR)
	;";


my $res = $dbh->selectall_arrayref($sql, { Slice => {} });

foreach(@$res){
  if ($_->{issue_id}){
    my $issue_id	 = ($_->{issue_id}); 
    my $itemnumber   = ($_->{itemnumber});

    my $item = Koha::Items->find($_->{itemnumber}); 
    my $itemlost = $item->itemlost;

	use POSIX qw(strftime);
	my $today = strftime "%Y-%m-%d", localtime;

	if ($itemlost == 0) {
		$item->itemlost("1");
	}

	$item->itemlost_on($today);
	$item->onloan("");
	$item->store;

	my $sth = $dbh->prepare("INSERT INTO old_issues SELECT * FROM issues WHERE issue_id = $issue_id;");
	my $res = $sth->execute();
	$sth = $dbh->prepare("UPDATE old_issues set note = 'Har rensats automatiskt' WHERE issue_id = $issue_id;");
	$res = $sth->execute();
	$sth = $dbh->prepare("DELETE FROM issues WHERE issue_id = $issue_id;");
	$res = $sth->execute();

	# bygg upp en rad att stoppa in i ub_statistics
	my $stat_branch = ($_->{branchcode});
	my $stat_type = "auto-removed";
	my $stat_other = ($_->{date_due});
	my $stat_itemtype = ($_->{itype});
	my $stat_location = ($_->{permanent_location});
	my $stat_biblionumber = ($_->{biblionumber});
	my $stat_title = ($_->{title});
	my $stat_author = ($_->{author});
	my $stat_callno = ($_->{itemcallnumber});
	my $stat_categorycode = ($_->{categorycode});
	my $stat_issue_note = ($_->{note});
	my $stat_issue_auto_renew = ($_->{auto_renew});

	my $stat_sql = "INSERT INTO ub_statistics (datetime, branch, type, other, itemnumber, itemtype, location, biblionumber, title, author, callno, categorycode, issue_note, issue_auto_renew) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?);";

	$sth = $dbh->prepare($stat_sql);
	$res = $sth->execute($today, $stat_branch, $stat_type, $stat_other, $itemnumber, $stat_itemtype, $stat_location, $stat_biblionumber, $stat_title, $stat_author, $stat_callno, $stat_categorycode, $stat_issue_note, $stat_issue_auto_renew);

  }
}
