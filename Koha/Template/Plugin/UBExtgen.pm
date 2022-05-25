package Koha::Template::Plugin::UBExtgen;
use Modern::Perl;
use Template::Plugin;
use base qw( Template::Plugin );
use Koha::Patrons;
use Koha::Patron::Debarments;
use C4::Koha;
use C4::Context;
use Data::Dumper;
use utf8;

sub GenPWAllowed {
    my ($self, $borrowernumber) = @_;
    my $patron = Koha::Patrons->search({ borrowernumber => $borrowernumber})->next();
    return isAllowed($patron);
}

sub DeniedReason {
  my ($self, $patron) = @_;
  if(!isEx($patron->categorycode())) { return "Endast för Allmänheten"; }
  if(isBlocked($patron)) { return "Låntagaren är spärrad"; }
  if(isExpired($patron)) { return "Giltighetstiden har gått ut"; }
  if(invalidCardnumber($patron)) { return "Lånekortsnumret inte giltigt"; }
  return "";
}

sub isAllowed {
  my ($patron) = @_;
  if(!isEx($patron->categorycode())) { return 0; }
  if(isBlocked($patron)) { return 0; }
  if(isExpired($patron)) { return 0; }
  if(invalidCardnumber($patron)) { return 0; }
  return 1;
}

sub isExpired {
  my ($patron) = @_;
  return $patron->is_expired();
}

sub isBlocked {
  my ($patron) = @_;

  if($patron->lost() && $patron->lost() ne "0") { return 1; }
  if($patron->gonenoaddress() && $patron->gonenoaddress() ne "0") { return 1; }
  if(isDebarred($patron)) { return 1; }
  return 0;
}

sub invalidCardnumber {
  my ($patron) = @_;
  my $cardnumber = $patron->cardnumber();

  if(($cardnumber !~ /^\d{10}$/) && ($cardnumber !~ /^2400\d{10}$/)) { return 1; }

  my $pnrattr = $patron->get_extended_attribute("PNR");
  my $pnr;
  my $pnr12;
  my $pnr12trunc;

  if($pnrattr) {
    $pnr = $pnrattr->attribute();
  }
  my $pnr12attr = $patron->get_extended_attribute("PNR12");
  if($pnr12attr) {
    $pnr12 = $pnr12attr->attribute();
    $pnr12trunc = substr($pnr12, 2, 10);
  }

  if($pnr && $pnr eq $cardnumber) { return 1; }
  if($pnr12 && $pnr12 eq $cardnumber) { return 1; }
  if($pnr12trunc && $pnr12trunc eq $cardnumber) { return 1; }

  return 0;
}

sub isDebarred {
  my ($patron) = @_;
  my $debarments = Koha::Patron::Debarments::GetDebarments({borrowernumber => $patron->borrowernumber()});

  foreach my $debarment (@{$debarments}) {
    my $comment = $debarment->{comment};
    if($comment =~ /^WR,/) { return 1; }
    if($comment =~ /^GU,/) { return 1; }
    if($comment =~ /^AV,/) { return 1; }
  }

  return 0;
}

sub isEx {
  my ($code) = @_;

  if($code eq "EX") { return 1; }
  if($code eq "UX") { return 1; }
  if($code eq "SR") { return 1; }
  if($code eq "FR") { return 1; }
  if($code eq "FX") { return 1; }

  return 0;
}

1;