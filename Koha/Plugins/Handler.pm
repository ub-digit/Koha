package Koha::Plugins::Handler;

# Copyright 2012 Kyle Hall
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

use Modern::Perl;

use File::Path qw(remove_tree);

use Module::Load qw(load);

use C4::Context;
use Koha::Plugins;
use Koha::Plugins::Methods;

BEGIN {
    my $pluginsdir = C4::Context->config("pluginsdir");
    my @pluginsdir = ref($pluginsdir) eq 'ARRAY' ? @$pluginsdir : $pluginsdir;
    push( @INC, @pluginsdir );
    pop @INC if $INC[-1] eq '.' ;
}

=head1 NAME

Koha::Plugins::Handler - Handler Module for running plugins

=head1 SYNOPSIS

  Koha::Plugins::Handler->run({ class => $class, method => $method, cgi => $cgi });
  $p->run();

=over 2

=cut

=item has_plugin_for_hook

Check whether or not there are any plugins for the specified hook, returning 0 if
no matching plugin exists, or 1 if there is at least one.

=cut

sub has_plugin_for_hook {
    my ( $class, $args ) = @_;

    # If plugins are disabled, no plugin can be available
    return 0 unless ( C4::Context->config("enable_plugins") || $args->{'enable_plugins'} );

    my $method = $args->{'method'};
    
    my @plugins = Koha::Plugins->new()->GetPlugins({
        method => $method
    });

    if (@plugins > 0) {
        return 1;
    } else {
        return 0;
    }
}

=item run_hook

Run all plugins for the specified hook in sequence. Each plugin in turn will get
input data according to the hook in question, and is assumed to return output data
in the same format as its input, so that they can be chained.

=cut

sub run_hook {
    my ( $class, $args ) = @_;
    my $params = $args->{'params'};
    return $params unless ( C4::Context->config("enable_plugins") || $args->{'enable_plugins'} );

    my $plugin_method = $args->{'method'};
    my @plugins = Koha::Plugins->new()->GetPlugins({
        method => $plugin_method
    });

    foreach my $plugin (@plugins) {
        $params = Koha::Plugins::Handler->run({
                class => $plugin->{'class'},
                method => $plugin_method,
                params => $params
            });
    }
    
    return $params;
}

=item run

Runs a plugin

=cut

sub run {
    my ( $class, $args ) = @_;

    return unless ( C4::Context->config("enable_plugins") || $args->{'enable_plugins'} );

    my $plugin_class  = $args->{'class'};
    my $plugin_method = $args->{'method'};
    my $cgi           = $args->{'cgi'};
    my $params        = $args->{'params'};

    my $has_method = Koha::Plugins::Methods->search({ plugin_class => $plugin_class, plugin_method => $plugin_method })->count();
    if ( $has_method ) {
        load $plugin_class;
        my $plugin = $plugin_class->new( { cgi => $cgi, enable_plugins => $args->{'enable_plugins'} } );
        return $plugin->$plugin_method( $params );
    } else {
        warn "Plugin does not have method $plugin_method";
        return;
    }
}

=item delete

Deletes a plugin

=cut

sub delete {
    my ( $class, $args ) = @_;

    return unless ( C4::Context->config("enable_plugins") || $args->{'enable_plugins'} );

    my $plugin_class = $args->{'class'};

    my $plugin_path = $plugin_class;
    $plugin_path =~ s/::/\//g;  # Take class name, transform :: to / to get path
    $plugin_path =~ s/$/.pm/;   # Add .pm to the end
    require $plugin_path;   # Require the plugin to have it's path listed in INC
    $plugin_path =
      $INC{$plugin_path};   # Get the full true path to the plugin from INC
    $plugin_path =~ s/.pm//;    # Remove the .pm from the end

    Koha::Plugins::Handler->run({
        class          => $plugin_class,
        method         => 'uninstall',
        enable_plugins => $args->{enable_plugins},
    });

    C4::Context->dbh->do( "DELETE FROM plugin_data WHERE plugin_class = ?", undef, ($plugin_class) );
    Koha::Plugins::Methods->search({ plugin_class => $plugin_class })->delete();

    unlink "$plugin_path.pm" or warn "Could not unlink $plugin_path.pm: $!";
    remove_tree($plugin_path);
}

1;
__END__

=back

=head1 AUTHOR

Kyle M Hall <kyle.m.hall@gmail.com>

=cut
