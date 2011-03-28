#!/usr/bin/perl

use Getopt::Long;
use Net::SMTP;
use HTML::TreeBuilder;
use LWP::UserAgent;

my @search = (
          { key => '35.*1.4', max => '1200'},
          { key => '135.*f2', max => '850'},
          { key => '100L',  max=> '750'},
          { key => '1D',  max => '1550'},
          { key => 'pocket', max => '200'},
          { key => '85.*1.2', max=>'1900'},
          { key => '5d', max=> '900'},
);

my $cl_location="sfbay";
my $cl_search_url='craigslist.org/search/';
my $category='pho';
my $query="canon";
my $search_type="A";
my $min_ask;
my $max_ask;
my $nofilter=0;
my $rcpt="gcamazon\@gmail.com";
my $nomail=0;

Getopt::Long::GetOptions('location|l=s' => \$cl_location,
                         'category|c=s' => \$category,
                         'query|q=s' => \$query,
                         'type|t=s' => \$search_type,
                         'min=i' => \$min_ask,
                         'max=i' => \$max_ask,
                         'all|a' => sub {$nofilter = 1;},
                         'nomail|n' => sub {$nomail = 1; },
                         'rcpt|r=s' => \$rcpt);

my $cl_url="http://" . $cl_location . ".$cl_search_url" . $category . '?' . "query=" . $query . '\&srchType=' . uc($search_type) . '\&minAsk=' . $min_ask . '\&maxAsk=' . $max_ask;
#my $tmp_file = "/tmp/cl.html";
#my $cmd="curl $cl_url > $tmp_file 2>/dev/null";
#print "cmd=$cmd\n";
#system($cmd);

my $response = LWP::UserAgent->new->request(
    HTTP::Request->new( GET => $cl_url)
);
unless ( $response->is_success() ) {
    warn "Couldn't get $cl_url: ", $response->status_line, "\n";
    return;
}

my $html_tree = HTML::TreeBuilder->new();
$html_tree->parse($response->content);
$html_tree->eof();
my @items = map {$_->as_text} $html_tree->look_down('_tag', 'p');

#Mar 10 - Canon WATERPROOF CAMERA CASE WP-DC300 - $100 (El Cerrito) pic

my $data='';

foreach my $item (@items) {
    next unless ( $item =~ /(.*?)\s+\-(.*)\-\s+\$(\d+)\s+(.*)/ );
    my ($date, $name, $ask, $location) = ($1, $2, $3, $4);
    if ( $nofilter) {
        print "$date\t$name\t$ask\t$location\n";
        $data .= "$date\t$name\t$ask\t$location\n";
        next;
    }
    foreach my $want (@search) {
        my $key = $want->{key};
        my $max = $want->{max};
        if ( $name =~ /$key/i && $ask <= $max) {
             print "$date\t$name\t$ask\t$location\n";
             $data .= "$date\t$name\t$ask\t$location\n";
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
   $smtp->datasend("Subject: CL search $query\r\n");
   $smtp->datasend("\r\n$data\r\n");
   my $ok = $smtp->dataend();
   print "smtp status : $ok\n";
   $smtp->quit;
}



