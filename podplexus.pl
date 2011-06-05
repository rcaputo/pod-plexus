#!/usr/bin/env perl

use warnings;
use strict;

# TODO - Until .zshenv kicks in.
use lib qw(/home/troc/projects/pod-plexus/pod-plexus/lib);

use Pod::Plexus;

### Main.

my $lib = Pod::Plexus::Library->new();

$lib->add_files(
	sub { my $path = shift(); (-f $path) && ($path =~ /\.pm$/) },
	"lib"
);

my $doc = $lib->get_document("lib/App/PipeFilter/Generic.pm");

$doc->collect_ancestry();
$doc->expand_commands();

#$doc->elementaldump();
#$doc->ppidump();
print $doc->render(), "\n";
