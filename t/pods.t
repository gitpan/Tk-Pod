#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: pods.t,v 1.4 2009/10/10 15:55:35 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use Tk;
use Tk::Pod::Text;

BEGIN {
    if (!eval q{
	use Test;
	1;
    }) {
	print "1..0 # skip no Test module\n";
	CORE::exit(0);
    }
}

use Tk;
my $mw = eval { MainWindow->new };
if (!$mw) {
    print "1..0 # cannot create MainWindow\n";
    CORE::exit(0);
}

plan tests => 4;

my $pt = $mw->PodText->pack;
for my $pod ('perl',       # pod in perl.pod
	     'perldoc',    # pod in script itself
	     'strict',     # sample pragma pod
	     'File::Find', # sample module pod
	    ) {
    $pt->configure(-file => $pod);
    ok($pt->cget(-file), $pod);
}

#MainLoop;

__END__
