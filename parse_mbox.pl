#!/usr/bin/env perl

use strict;
use warnings;

$|=1;

use JSON;
use Email::Folder;
use Data::Dump::Streamer 'Dump', 'Dumper';

use lib 'lib';
use EmailParse;

my $mbox = shift;
die "Can't find $mbox" if !-e $mbox;

$mbox = Email::MimeFolder->new($mbox) or die;
print Dumper($mbox);

my $parser = EmailParse->new(output_file => 'amazon.json');

while (my $email = $mbox->next_message) {
  print "Got message $email\n";

  next if            $email->header("Subject") =~ m/FOLDER INTERNAL DATA/;
  next if            $email->header("Subject") =~ m/Successful update of/;
  Dump($email->header('From'));
  my ($plugin) = $parser->find_plugin($email->header("From"));
  next unless $plugin;

  my @header_list = $email->header_pairs;
  while (@header_list) {
    my ($header, $content) = splice(@header_list, 0, 2, ());
    # print "$header: $content\n";
  }

  print "\n\n";

  for my $part ($email->parts) {
    # print "Part with ct: ", $part->content_type, "\n";

    next unless $part->content_type =~ m!^text/html!;

    $parser->parse($plugin, $part->body, $email->header('Date'));
  }
}

$parser->finish();

package Email::MimeFolder;
use base 'Email::Folder';
use Email::MIME;
sub bless_message {
  Email::MIME->new($_[1]);
}

__END__

