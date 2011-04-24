#!/usr/bin/perl

use Getopt::Long;
use Net::SMTP;
use HTML::TreeBuilder;
use LWP::UserAgent;
use Data::Dumper;

my @search = (
          { key => 'canon', max => '1200'},
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

my $data='';

sub process($) {
    my $url = shift;
    my $response = LWP::UserAgent->new->request(
        HTTP::Request->new( GET => $url)
    );
    unless ( $response->is_success() ) {
        warn "Couldn't get $url: ", $response->status_line, "\n";
        return;
    }

    my $html_tree = HTML::TreeBuilder->new();
    $html_tree->parse($response->content);
    $html_tree->eof();

    my @raw_items = $html_tree->look_down('class', 'topictitle');

    my @items = map {$_->as_text} @raw_items;

    #print Dumper(@items);

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
}

for (my $i = 0; $i < 10 ; $i++) {
    my $fm_url="http://www.fredmiranda.com/forum/board/10/$i";
    process($fm_url);
}

sub smtpsend () {
   my $smtp = Net::SMTP->new ('gmail-smtp-in.l.google.com',
                               Hello => 'comcast.com');
   $smtp->mail("defencer\@gmail.com");
   $smtp->to($rcpt);
   $smtp->data();
   $smtp->datasend("From : defencer\@gmail.com\n");
   $smtp->datasend("To: $rcpt\n");
   $smtp->datasend("Subject: CL search $query\r\n");
   $smtp->datasend("\r\n$data\r\n");
   my $ok = $smtp->dataend();
   print "smtp status : $ok\n";
   $smtp->quit;
}

if ( ! $nomail && $data ) {
    smtpsend();
}

