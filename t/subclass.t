#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

# Subclassing test --- use Tk::ROText instead of Tk::More
# as the pager in the PodText widget

use strict;

use Tk;
use Tk::Pod;

BEGIN {
    if (!eval q{
	use Test;
	1;
    }) {
	print "1..0 # skip tests only work with installed Test module\n";
	CORE::exit(0);
    }

    if ($] < 5.006) {
	print "1..0 # skip subclassing does not work with perl 5.005 and lesser\n";
	CORE::exit(0);
    }
}

my $mw = eval { MainWindow->new };
if (!$mw) {
    print "1..0 # cannot create MainWindow\n";
    CORE::exit(0);
}
$mw->geometry("+1+1"); # for twm

plan tests => 1;

{
    package Tk::MyMore;
    use base qw(Tk::Derived Tk::ROText);
    Construct Tk::Widget "MyMore";
    sub Populate {
	my($w, $args) = @_;
	$w->SUPER::Populate($args);
	$w->Advertise(text => $w); # XXX hmmmm....
	$w->ConfigSpecs(-searchcase => ['PASSIVE'],
			-helpcommand => ['PASSIVE'],
		       );
    }
}

{
    package Tk::MyPodText;
    use base qw(Tk::Pod::Text);
    Construct Tk::Widget "MyPodText";
    sub More_Module { }
    sub More_Widget { "MyMore" }
}

{
    package Tk::MyPod;
    use base qw(Tk::Pod);
    Construct Tk::Widget "MyPod";
    sub Pod_Text_Module { }
    sub Pod_Text_Widget { "MyPodText" }
}

$mw->withdraw;
my $pod = $mw->MyPod;
$pod->geometry('+1+1'); # for twm
$pod->configure(-file => "perl.pod");
$mw->update;
ok(1);

if (!$ENV{PERL_INTERACTIVE_TEST}) {
    $mw->after(1*1000, sub { $mw->destroy });
}

MainLoop;
