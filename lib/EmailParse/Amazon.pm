package EmailParse::Amazon;

=head1 NAME

EmailParse::Amazon

=head1 DESCIPTION

Extracts item-ordered data from Amazon confirmation emails. Returns an
arrayref of items found, each entry contains:

=over

=item email_date

=item order_id

=item order_link

=item order_date

=item image_link

=item name

=item price

=back

=cut

use strict;
use warnings;

use Time::ParseDate;
use DateTime;
use HTML::TreeBuilder;

sub parse_email {
    my ($class, $email, $origin_time) = @_;

    if($origin_time =~ /\D/) {
        $origin_time = parsedate($origin_time);
    }

    my $tree = HTML::TreeBuilder->new_from_content($email);

    # $tree->dump;
    my @entries;

    my $first_order_details_ele = $tree->look_down('_tag' => 'table', id => 'orderDetails');
    my $main_tr = $first_order_details_ele->look_up('_tag' => 'tr');
    my $order_data;
    while($main_tr) {
        my $order_details_ele = $main_tr->look_down('_tag' => 'table', id => 'orderDetails');
        if($order_details_ele) {
            my $order_id_ele = $order_details_ele->look_down('_tag' => 'a');
            my $order_id = $order_id_ele->as_text();
            my $order_link = $order_id_ele->attr('href');
            my $order_date_ele = $order_details_ele->look_down('_tag' => 'span');
            my $order_date = $order_date_ele->as_text();
            $order_date =~ s/Placed on //;
            # WTF Amazon, one "Placed on" text in one email also contains a Dow..
            $order_date =~ s/(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday), //;
            my ($order_epoch, $error) = parsedate($order_date);
            print "$order_date, $order_epoch, $error\n";

            $order_data = { order_id => $order_id,
                            order_link => $order_link,
                            order_date => DateTime->from_epoch(epoch => $order_epoch, time_zone=>'Europe/London')->iso8601,
                            email_date => DateTime->from_epoch(epoch => $origin_time, time_zone=>'Europe/London')->iso8601,
            };
        }

        my $item_ele = $main_tr->look_down('_tag' => 'table', 'id' => 'itemDetails');
        if($item_ele) {       
            my $image_ele = $item_ele->look_down('_tag' => 'td', class => 'photo');
            my $image_link = $image_ele->look_down('_tag' => 'img')->attr('src');
            my $name_ele = $image_ele->right()->look_down('_tag' => 'a');
            my $item_link = $name_ele->attr('href');
            my $item_name = $name_ele->as_text();
            print $item_name, "\n";
            print $order_data->{order_date}, "\n";
            my $price_ele = $image_ele->right()->right();

            # Ignoring updated orders for now? they have no prices on..
            next if !$price_ele;

            my $price = $price_ele->as_text;
            $price =~ s/\243//;

            push @entries, {
                %$order_data,
                    image_link => $image_link,
                    name => $item_name,
                    price => $price,
            };
        }
    } continue {
        $main_tr = $main_tr->right();
    }

    return \@entries;
}

1;
