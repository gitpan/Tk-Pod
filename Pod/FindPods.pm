# -*- perl -*-

#
# $Id: FindPods.pm,v 1.4 2001/06/18 18:38:14 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven.rezic@berlin.de
# WWW:  http://www.rezic.de/eserte/
#

package Tk::Pod::FindPods;

=head1 NAME

Tk::Pod::FindPods - find PODs installed on the current system


=head1 SYNOPSIS

    use Tk::Pod::FindPods qw/pod_find/;

    %pods = pod_find(-categorized => 1, -usecache => 1);

=head1 DESCRIPTION

=cut

use base 'Exporter';
use strict;
use vars qw($VERSION @EXPORT_OK
	    %pods $has_cache
	    $init_done %arch $arch_re %seen_dir $curr_dir %args);

@EXPORT_OK = qw/%pods $has_cache pod_find/;

$VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

use File::Find;
use File::Spec;
use Config;

sub init {
    %arch = guess_architectures();
    $arch_re = "(" . join("|", map { quotemeta $_ } ("mach", keys %arch)) . ")";
    #warn $arch_re;
    $init_done++;
}

=head2 pod_find

The B<pod_find> method scans the current system for available POD
documentation. The keys of the returned hash are the names of the
modules or PODs (C<::> substituted by C</>). The values are the
corresponding filenames.

If C<-categorized> is specified, then the returned hash has an extra
level with three categories: B<perl> (for core language
documentation), B<pragmata> (for pragma documentation like L<var|var>
or L<strict|strict>) and B<modules> (core or CPAN modules).

If C<-usecache> is specified, then the list of PODs is cached in a
temporary directory.

=cut

sub pod_find {
    my(@args) = @_;
    if (ref $args[0] eq 'HASH') {
	%args = %{ $args[0] };
    } else {
	%args = @args;
    }

    undef $has_cache;

    if ($args{-usecache}) {
	my $perllocal = File::Spec->catfile($Config{'installarchlib'},'perllocal.pod');
	my $cache_file = _cache_file();
	if (!-r $cache_file || -M $perllocal > -M $cache_file) {
	    %pods = LoadCache();
	    if (%pods) {
		$has_cache = 1;
		return %pods;
	    }
	} else {
	    warn "$perllocal is more recent than cache file $cache_file";
	}
    }

    init() unless $init_done;

    %seen_dir = ();
    undef $curr_dir;
    %pods = ();

    foreach my $inc (@INC) {
	next if $inc eq '.'; # ignore current directory
	$curr_dir = $inc;
	find(\&wanted, $inc);
    }

    %pods;
}

sub wanted {
    if (-d) {
	if ($seen_dir{$File::Find::name}) {
	    $File::Find::prune = 1;
	    return;
	} else {
	    $seen_dir{$File::Find::name}++;
	}
    }

    if (-f && /\.(pod|pm)$/) {
	(my $name = $File::Find::name) =~ s|^$curr_dir/?||;
	$name = simplify_name($name);

	my $hash;
	if ($args{-categorized}) {
	    my $type = type($name);
	    $hash = $pods{$type} || do { $pods{$type} = {} };
	} else {
	    $hash = \%pods;
	}

	if (exists $hash->{$name}) {
	    if ($hash->{$name} =~ /\.pod$/ && $File::Find::name =~ /\.pm$/) {
		return;
	    }
	    my($ext1) = $hash->{$name}    =~ /\.(.*)$/;
	    my($ext2) = $File::Find::name =~ /\.(.*)$/;
	    if ($ext1 eq $ext2) {
		warn "Clash: $hash->{$name} <=> $File::Find::name";
		return;
	    }
	}
	$hash->{$name} = $File::Find::name;
    }
}

sub simplify_name {
    my $f = shift;
    $f =~ s|^\d+\.\d+\.\d+/?||; # strip perl version
    $f =~ s|^$arch_re|| if defined $arch_re; # strip machine
    $f =~ s/\.(pod|pm)$//;
    $f =~ s|^pod/||;
    if ($^O eq 'MSWin32') { # case-insensitive :-(
	$f =~ s|^pod/perl|perl|i;
    }
    $f;
}

sub type {
    local $_ = shift;
    if    (/^perl/) { return "perl" }
    elsif (/^[a-z]/ && !/^(mod_perl|lwpcook|cgi_to_mod_perl)/) { return "pragma" }
    else            { return "mod" }
}

sub guess_architectures {
    my %arch;
    my @configs;
    foreach my $inc (@INC) {
	push @configs, glob("$inc/*/Config.pm");
    }
    foreach my $config (@configs) {
	my($arch) = $config =~ m|/([^/]+)/Config.pm|;
	if (open(CFG, $config)) {
	    while(<CFG>) {
		/archname.*$arch/ && do {
		    $arch{$arch}++;
		    last;
		};
	    }
	    close CFG;
	} else {
	    warn "cannot open $config: $!";
	}
    }
    %arch;
}

sub is_site_module {
    my $path = shift;
    if ($^O eq 'MSWin32') {
	return $path =~ m|[/\\]site[/\\]lib[/\\]|;
    }
    $path =~ /^(
                $Config{'installsitelib'}
               |
		$Config{'installsitearch'}
	       )/x;
}

sub _cache_file {
    (my $ver = $])  =~ s/[^a-z0-9]/_/gi;
    (my $os  = $^O) =~ s/[^a-z0-9]/_/gi;
    my $uid  = $<;

    if (File::Spec->can('tmpdir')) {
        File::Spec->catfile(File::Spec->tmpdir, join('_', 'pods',$ver,$os,$uid));
      } else {
        File::Spec->catfile(($ENV{TMPDIR}||"/tmp"), join('_', 'pods',$ver,$os,$uid));
      }
}

=head2 WriteCache

Write the POD cache. The cache is written to the temporary directory.
The file name is constructed from the perl version, operation system
and user id.

=cut

sub WriteCache {
    require Data::Dumper;

    if (!open(CACHE, ">" . _cache_file())) {
	warn "Can't write to cache file " . _cache_file();
    } else {
	my $dd = Data::Dumper->new([\%pods], ['pods']);
	$dd->Indent(0);
	print CACHE $dd->Dump;
	close CACHE;
    }
}

=head2 LoadCache()

Load the POD cache, if possible.

=cut

sub LoadCache {
    my $cache_file = _cache_file();
    if (-r $cache_file) {
	return if $< != (stat($cache_file))[4];
	require Safe;
	my $c = Safe->new('Tk::Pod::FindPods::SAFE');
	$c->rdo($cache_file);
	if (keys %$Tk::Pod::FindPods::SAFE::pods) {
	    %pods = %$Tk::Pod::FindPods::SAFE::pods;
	    return %pods;
	}
    }
    ();
}

return 1 if caller;

package main;

require Data::Dumper;
print Data::Dumper->Dumpxs([{Tk::Pod::FindPods::pod_find(-categorized => 0, -usecache => 0)}],[]);

__END__

=head1 SEE ALSO

Tk::Tree(3).

=head1 AUTHOR

Slaven Rezic <F<slaven.rezic@berlin.de>>

Copyright (c) 2001 Slaven Rezic.  All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the same
terms as Perl itself.

=cut
