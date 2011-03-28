#!/usr/bin/perl

use Getopt::Long;
use Net::SMTP;
use HTML::TreeBuilder;
use LWP::UserAgent;
use Data::Dumper;

my @search = (
          { key => 'thinkpad', max => '700'},
          { key => 'new\s+balance', max => '35'},
          { key => 'DSLR', max => '400'},
          { key => 'drugstore', max => '100'},
);

my $nofilter=0;
my $rcpt="gcamazon\@gmail.com";
my $nomail=1;
my $debug=0;

Getopt::Long::GetOptions(
                         'all|a' => sub {$nofilter = 1;},
                         'nomail|n' => sub {$nomail = 1; },
                         'rcpt|r=s' => \$rcpt,
                         'debug' => sub {$debug = 1;} );

my $ds_url="http://dealsea.com";

my $response = LWP::UserAgent->new->request(
    HTTP::Request->new( GET => $ds_url)
);
unless ( $response->is_success() ) {
    warn "Couldn't get $ds_url: ", $response->status_line, "\n";
    return;
}

my $html_tree = HTML::TreeBuilder->new();
$html_tree->parse($response->content);
$html_tree->eof();

my @raw_items = $html_tree->look_down( '_tag', 'a', sub { return unless ($_[0]->attr('href') && $_[0]->attr('href') =~ /view\-deal/); });

my @items = map {$_->as_text} @raw_items;

#print Dumper(@items);

my $data='';

foreach my $item (@items) {
    my $price;
    if ( $item =~ /\$(\d+)/) {
        $price = $1;
    }
    if ($nofilter) {
        print "$item\n";
    }
    foreach my $want (@search) {
        my $key = $want->{key};
        my $max = $want->{max};
        if ( $item =~ /$key/i && $price <= $max) {
             $data .= "$item\n";
             print "$item\n";
        }
    }
}

if ( ! $nomail && $data ) {
    smtpsend();
}

sub smtpsend () {
   my $smtp = Net::SMTP->new ('smtp.proofpoint.com',
                               Hello => 'gta.us.proofpoint.com');
   $smtp->mail("kzhang\@proofpoint.com");
   $smtp->to($rcpt);
   $smtp->data();
   $smtp->datasend("From : kzhang\@proofpoint.com\n");
   $smtp->datasend("To: $rcpt\n");
   $smtp->datasend("Subject: DS search $query\r\n");
   $smtp->datasend("\r\n$data\r\n");
   my $ok = $smtp->dataend();
   print "smtp status : $ok\n";
   $smtp->quit;
}



