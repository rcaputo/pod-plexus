#!/usr/bin/env perl

use warnings;
use strict;

# TODO - Until .zshenv kicks in.
use lib qw(/home/troc/projects/pod-plexus/pod-plexus/lib);

use Pod::Plexus;

# Sample usage:
#   ./podplexus.pl lib/App/PipeFilter/Generic.pm lib

my ($input_path, @gather_roots) = @ARGV;

my $lib = Pod::Plexus::Library->new();

$lib->add_files(
	sub {
		my $path = shift();
		# TODO - The .pm requirement doesn't consider extension-less
		# binaries, which is sad.  Rely on Dist::Zilla's smarter
		# gathering.
		(-f $path) && ($path =~ /\.pm$/);
	},
	@gather_roots
);

my $doc = $lib->get_module($input_path);

$doc->collect_data();
$doc->expand_commands();

#$doc->elementaldump();
#$doc->ppidump();

print $doc->render(), "\n";
