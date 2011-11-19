package Pod::Plexus::Cli;

=abstract Implementation of the Pod::Plexus command line utility.

=cut

use Moose;
with 'MooseX::Getopt';

use Pod::Plexus::Distribution;
use File::Find;


=method new_with_options

[% s.name %] is inherited from MooseX::Getopt.  It creates one new [%
m.package %] object from command line parameters.  See L</PUBLIC
ATTRIBUTES> for constructor options and the command line switches that
populate them.

=cut


=attribute lib

The "[% s.name %]" attribute contains a list of distribution
directories from which modules will be collected, indexed and possibly
rendered.  By default it contains a single directory: "./lib".

"[% s.name %]" is populated by one or more --[% s.name %] command line
switches.

=cut

has lib => (
	is            => 'rw',
	isa           => 'ArrayRef[Str]',
	required      => 1,
	default       => sub { [ './lib' ] },
	documentation => 'one or more distribution root directories (default: lib)',
);


=attribute module

"[% s.name %]" contains an array of specific modules to render.  All
eligible files will be rendered if none are specified.

"[% s.name %]" is populated by one or more --[% s.name %] command line
switches.

=cut

has module => (
	is            => 'rw',
	isa           => 'ArrayRef[Str]',
	lazy          => 1,
	default       => sub {
		my $self = shift();
		return [ sort $self->_distribution()->get_known_module_names() ];
	},
	documentation => 'modules to render docs for (default: all found)',
);


=attribute verbose

The "[% s.name %]" attribute (and therefore the --[% s.name %] command
line flag) turns on additional stderr information when true.

=cut

has verbose => (
	is            => 'rw',
	isa           => 'Bool',
	default       => 0,
	documentation => 'enable a lot of stderr output',
);


has _distribution => (
	is      => 'ro',
	isa     => 'Pod::Plexus::Distribution',
	default => sub {
		my $self = shift();
		Pod::Plexus::Distribution->new(
			verbose => $self->verbose(),
		);
	},
);


=method is_indexable_file

[% s.name %] tests whether a file at a RELATIVE_PATH is eligible to
be documented.  Currently only ".pm" files are eligible.

=example method collect_lib_files

=cut

sub is_indexable_file {
	my ($self, $qualified_path) = @_;

	return unless $qualified_path =~ /\.pm$/;
	return unless $qualified_path =~ /^lib/;
	return if $qualified_path =~ /~$/;

	return 1;
}


=method collect_lib_files

[% s.name %] collects files in the distribution that are eligible for
documenting.  It uses File::Find to descend into directories in the
"lib" attribute.  Each file that is_indexable_file() approves is added
to the distribution for later processing.

=cut

sub collect_lib_files {
	my $self = shift();

	$self->verbose() and warn "Collecting distribution modules...\n";

	find(
		{
			wanted => sub {
				return unless -f $_;
				return unless $self->is_indexable_file($_);
				return if $self->_distribution()->has_module_by_file($_);

				$self->_distribution()->add_file($_);
			},
			no_chdir => 1,
		},
		@{$self->lib()},
	);
}


=method run

[% s.name %] runs the Pod::Plexus command-line implementation.  All
runtime parameters are taken from [% m.package %] public attributes.
Thanks to MooseX::Getopt, those attributes are automatically populated
from corresponding command line arguments.

[% s.name %] collects all the modules in all the "lib" directories.
Each module is added to the Pod::Plexus::Distribution so that it's
known by the time cross references are resolved.  Each module is
scanned by Pod::Plexus::Module, which finds and caches pertinent
information in a Pod::Plexus::Module::Code or
Pod::Plexus::Module::Docs object for manipulation and rendering into
POD later.

=example method run

=cut

sub run {
	my $self = shift();

	# Collect files from the libraries.
	# This minimally processes the files.

	$self->collect_lib_files();

	my @errors;

	# This is a parsing, collection and error checking pass.
	# Cross-references aren't resolved.  Nothing is rendered yet.

	MODULE: foreach my $module_name (@{$self->module()}) {
		my $module_object = $self->_distribution()->get_module($module_name);

		unless ($module_object) {
			push @errors, "Can't find $module_name in distribution.";
			next MODULE;
		}

		push @errors, $module_object->cache_structure();
	}

	if (@errors) {
		warn "$_\n" foreach @errors;
		exit 1;
	}

	# This pass tries to find and inspect external referents.

	MODULE: foreach my $module_name (@{$self->module()}) {
		my $module_object = $self->_distribution()->get_module($module_name);

		my $rendered_pod = $module_object->render_as_pod();

		# TODO - Write to a file, if requested.

		print(
			"----------\n",
			"----------\n",
			"----------\n",
			$rendered_pod,
			"----------\n",
			"----------\n",
			"----------\n",
		);
	}

	# TODO - Render to files, if appropriate.

	#my $index = $distribution->generate_index();
	#my $toc = $distribution->generate_toc();

	# Successful exit.

	return 0;
}

no Moose;

1;
