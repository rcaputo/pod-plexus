package Pod::Plexus::Cli;

=abstract Implementation of the Pod::Plexus command line utility.

=cut

use Moose;
with 'MooseX::Getopt';

use Pod::Plexus::Distribution;
use File::Find;


=method new_with_options

[% s.name %] constructs one new [% m.package %] object, using
values from the command line to populate constructor parameters.
See L</PUBLIC ATTRIBUTES> for constructor options and the command line
switches that populate them.

=cut


=skip method usage

=skip attribute usage

=skip attribute ARGV

=skip method extra_argv

=skip attribute extra_argv

=skip method help_flag

=skip attribute help_flag

=skip method process_argv

=cut


=attribute lib

[% s.name %] contains a list of distribution directories from which
modules will be collected, indexed and possibly rendered.  By default
it contains a single directory: "./lib".

[% s.name %] is populated by one or more --[% s.name %] command line
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

[% s.name %] is an array of specific modules to render.  All eligible
files will be rendered if none are specified.

[% s.name %] is populated by one or more --[% s.name %] command line
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


has verbose => (
	is            => 'rw',
	isa           => 'Bool',
	default       => 0,
	documentation => 'enable a lot of stderr output',
);


=attribute _distribution

[% s.name %] contains a Pod::Plexus::Distribution object.  This
object is populated and driven by [% m.package %].

[% s.name %] is populated by the --[% s.name %] command line switch.

=example attribute _distribution

=cut

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

=example method is_indexable_file

=cut

sub is_indexable_file {
	my ($self, $qualified_path) = @_;

	return unless $qualified_path =~ /\.pm$/;
	return unless $qualified_path =~ /^lib/;
	return if $qualified_path =~ /~$/;

	return 1;
}


=method collect_lib_files

[% s.name %] collects files that are eligible for documenting.  It
uses File::Find to descend into directories in the "lib" directories.
Each file that is_indexable_file() approves is added to the
distribution for later processing.

=example method collect_lib_files

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

[% s.name %] runs the Pod::Plexus command-line interface.  All
runtime parameters are taken from [% m.package %] public attributes.
Thanks to MooseX::Getopt, those attributes are automatically populated
from corresponding command line arguments.

[% s.name %] collects all the modules in all the lib() directories.
Each module is added to the Pod::Plexus::Distribution so that it's
known by the time cross references are resolved.

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

		print $rendered_pod;
	}

	# TODO - Render to files, if appropriate.

	#my $index = $distribution->generate_index();
	#my $toc = $distribution->generate_toc();

	# Successful exit.

	return 0;
}

no Moose;

1;
