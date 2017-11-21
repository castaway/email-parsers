package EmailParse;

=head1 NAME

EmailParse

=head1 DESCRIPTION

Email parsing fun - loads plugins under EmailParse::, attempts to find
correct plugin, runs plugin to collect results, dumps all results to a
file once done.

=head1 ATTRIBUTES

=head2 plugins

Map of plugin name/match string to name of plugin class. Auto-loaded using L<Module::Find>.

=head2 results

Storage for the array of results from running the plugins.

=head2 output_file

If set, L</finish> will write JSON to this file.

=head1 METHODS

=cut

use strict;
use warnings;

use Moo;
use Module::Find;
use JSON;
use Data::Dump::Streamer 'Dump', 'Dumper';

has plugins => ( is => 'rw', builder => '_build_plugins' );
has results => ( is => 'rw', default => sub { [] } );
has output_file => ( is => 'rw' );

sub _build_plugins {
    my @plugin_list = findallmod('EmailParse');
    my %plugins = map { my $name = $_; $name =~ s{EmailParse::}{}; ( lc($name) => $_ ) } @plugin_list;
    
    for (values %plugins) {
        eval "use $_; 1;" or die "can't load $_: $@"
    }
    return \%plugins;
}

=head2 find_plugin

Pass a string to match on, typically the "From" header of an
email. Returns the plugin class to use to parse items of that type.

=cut

sub find_plugin {
    my ($self, $from) = @_;

    my ($plugin) = grep { $from =~ m/$_/i; } keys(%{ $self->plugins });

    return $self->plugins->{$plugin};
}

=head2 parse

Pass a plugin class (from L</find_plugin>) the html portion of an
email, and the email date. Extracts and stores the items from the html
into the L</results> attribute. An arrayref of items are also returned.

=cut

sub parse {
    my ($self, $plugin, $html, $date) = @_;

    my $items = $plugin->parse_email($html, $date);

    if(!@$items) {
        warn "No items found in email body";
        print $html;
    }

    #Dump $items;
    push @{$self->results}, @$items;

    return $items;
}

=head2 finish

Indicates parsing is done, outputs the results as JSON to the
L</output_file> if set, or STDOUT if not.

=cut

sub finish {
    my ($self) = @_;

    if($self->output_file) {
        open my $outfh, '>', $self->output_file or die "Can't open " . $self->output_file . " for writing ($!)";
        print $outfh JSON->new->pretty(1)->encode($self->results);
        close $outfh;
    } else {
        print encode_json($self->results);
    }

    $self->results([]);
}

1;
