package Pod::Plexus::Cli;

=abstract The Pod::Plexus command line utility implementation.

=cut

use Moose;
with 'MooseX::Getopt';

use Pod::Plexus::Library;
use File::Find;

=method new_with_options

[% ss.name %] constructs one new [% mod.package %] object, using
values from the command line to populate constructor parameters.
See L</PUBLIC ATTRIBUTES> for constructor options and the command line
switches that populate them.

=cut


=skip all usage

=skip attribute ARGV

=skip all extra_argv

=skip all help_flag

=skip method process_argv

=cut


=attribute lib

[% ss.name %] contains a list of library directories from which
modules will be collected, indexed and possibly rendered.  By default
it contains a single directory: "./lib".

[% ss.name %] is populated by one or more --[% ss.name %] command line
switches.

=cut

has lib => (
	is            => 'rw',
	isa           => 'ArrayRef[Str]',
	required      => 1,
	default       => sub { [ './lib' ] },
	documentation => 'one or more library root directories (default: lib)',
);


=attribute module

[% ss.name %] is an array of specific modules to render.  All eligible
files will be rendered if none are specified.

[% ss.name %] is populated by one or more --[% ss.name %] command line
switches.

=cut

has module => (
	is            => 'rw',
	isa           => 'ArrayRef[Str]',
	lazy          => 1,
	default       => sub {
		my $self = shift();
		return [ sort $self->_library()->get_module_names() ];
	},
	documentation => 'modules to render docs for (default: all found)',
);


=attribute _library

[% ss.name %] contains a Pod::Plexus::Library object.  This object is
populated and driven by [% mod.package %].

[% ss.name %] is populated by the --[% ss.name %] command line switch.

=cut

has _library => (
	is      => 'ro',
	isa     => 'Pod::Plexus::Library',
	default => sub { Pod::Plexus::Library->new() },
);


=method is_indexable_file

[% ss.name %] tests whether a file at a RELATIVE_PATH is eligible to
be documented.  Currently only ".pm" files are eligible.

=example is_indexable_file()

=cut

sub is_indexable_file {
	my ($self, $qualified_path) = @_;
	return unless $qualified_path =~ /\.pm$/;
	return 1;
}


=method collect_lib_files

[% ss.name %] collects files that are eligible for documenting.  It
uses File::Find to descend into directories in the "lib" directories.
Each file that is_indexable_file() approves is added to the library
for later processing.

=example collect_lib_files()

=cut

sub collect_lib_files {
	my $self = shift();

	find(
		{
			wanted => sub {
				return unless -f $_;
				return unless $self->is_indexable_file($_);
				return if $self->_library()->has_file($_);

				$self->_library()->add_file($_);
			},
			no_chdir => 1,
		},
		@{$self->lib()},
	);
}


=method run

[% ss.name %] runs the Pod::Plexus command-line interface.  All
runtime parameters are taken from [% mod.package %] public attributes.
Thanks to MooseX::Getopt, those attributes are automatically populated
from corresponding command line arguments.

[% ss.name %] collects all the modules in all the lib() directories.
Each module is added to the Pod::Plexus library so that it's known by
the time cross references are resolved.

=example run()

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
		my $doc_object = $self->_library()->get_document($module_name);

		unless ($doc_object) {
			push @errors, "Can't find $module_name in library.";
			next MODULE;
		}

		$doc_object->prepare_to_render(\@errors);
	}

	if (@errors) {
		warn "$_\n" foreach @errors;
		exit 1;
	}

	# This pass tries to resolve cross references.

	# TODO - Old way?
	MODULE: foreach my $module_name (@{$self->module()}) {
		my $doc_object = $self->_library()->get_document($module_name);
		#$doc_object->resolve_references();
	}

	if (@errors) {
		warn "$_\n" foreach @errors;
		exit 1;
	}

	# This pass tries to find and inspect external referents.

	MODULE: foreach my $module_name (@{$self->module()}) {
		my $doc_object = $self->_library()->get_document($module_name);

		my $rendered_pod = $doc_object->render_as_pod();

		# TODO - Write to a file, if requested.

		print $rendered_pod, "\n\n------------------------------------\n\n";
	}

	# TODO - Render to files, if appropriate.

	#my $index = $library->generate_index();
	#my $toc = $library->generate_toc();

	# Successful exit.

	return 0;
}

no Moose;

1;
