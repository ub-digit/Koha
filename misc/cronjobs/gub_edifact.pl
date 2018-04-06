#!/usr/bin/perl
use Modern::Perl;
use utf8;

use C4::Context;
use Log::Log4perl qw(:easy);
use Koha::Database;
use File::Path qw(make_path);
use File::Spec::Functions;

my $base_path = C4::Context->preference('GubEdifactBasedir') || "/tmp/edifact_messages";
my $log_file = catfile($base_path, 'gub_edifact.log');
# logging set to trace as this may be what you
# want on implementation
Log::Log4perl->easy_init(
    {
        level => $INFO,
        file  => ">>$log_file",
    }
);

my $logger = Log::Log4perl->get_logger();
sub log_exit {
    my ($error) = @_;
    $logger->error($error);
    exit 1;
}

my $schema = Koha::Database->new()->schema();

my @reopened_orders_to_keep = $schema->resultset('EdifactMessage')->search(
    {
        message_type => 'ORDERS',
        status       => 'Pending',
        deleted       => 0,
    }, {
        select => [
            'basketno',
            { count => 'basketno', -as => 'count_basketno'},
            { max => 'id', -as => 'max_id'},
        ],
        group_by => [
            'basketno'
        ],
        having => {
            'count_basketno' => { '>', 1 }
        },
    }
);

foreach my $order (@reopened_orders_to_keep) {
    my $max_id = $order->get_column('max_id');
    my $basketno = $order->get_column('basketno');

    my $orders_to_delete = $schema->resultset('EdifactMessage')->search(
        {
            message_type => 'ORDERS',
            status       => 'Pending',
            deleted => 0,
            basketno => $basketno,
            id => {'<>', $max_id}
        }
    );
    $orders_to_delete->update({ deleted => 1});
}

# @TODO: filter out non active?
#my @vendors = $schema->resultset('Aqbookseller')->search(undef, {
#        prefetch => 'vendor_edi_accounts' # Don't need this after all
#});

my $vendors_path = catfile($base_path, 'vendors');
my $errors;

$logger->info("Started");

make_path($vendors_path, {
    error => $errors,
});
log_exit("Can't create ${vendors_path}: $errors") if ($errors);

my @vendors = $schema->resultset('Aqbookseller')->all();
foreach my $vendor (@vendors) {
    my $vendor_dirname = $vendor->name;
    $vendor_dirname =~  s/\W/_/g;

    # Transliterate, hmm??
    $vendor_dirname =~ tr/åäöÅÄÖ/aaoAAO/;

    my $vendor_path = catfile($vendors_path, $vendor_dirname);
    make_path($vendor_path, {
        errors => $errors,
    });
    log_exit("Can't create ${vendor_path}: $errors") if ($errors);

    my $vendor_messages_path = catfile($vendor_path, 'messages');
    make_path($vendor_messages_path, {
        error => $errors,
    });
    log_exit("Can't create ${vendor_messages_path}: $errors") if ($errors);

    # Pending messages (join and collaspe in main query would be more efficient,
    # should fix even if performance difference will not matter at all)
    my @pending_orders = $schema->resultset('EdifactMessage')->search(
        {
            message_type => 'ORDERS',
            vendor_id    => $vendor->id,
            status       => 'Pending',
            deleted       => 0,
        }
    );
    # @TODO: Possible encoding issues?
    foreach my $order (@pending_orders) {
        my $filename = catfile($vendor_messages_path, $order->filename);
        open(my $fh, ">", $filename) or log_exit("Can't open $filename");
        print $fh $order->raw_msg;
        close($fh);
        $order->status('Processed');
        $order->update;
    }
}
$logger->info("Finished");
