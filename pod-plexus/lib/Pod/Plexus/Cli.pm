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

=skip attribute usage

=skip attribute ARGV

=skip attribute extra_argv

=skip attribute help_flag

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
	default       => sub { [ ] },
	documentation => 'modules to render docs for (default: all found)',
);


=attribute podroot

[% ss.name %] defines the root directory where rendered documentation
will be deposited.  The directory must not previously exist.

[% ss.name %] is populated by one or more --[% ss.name %] command line
switches.

=cut

has podroot => (
	is            => 'rw',
	isa           => 'Str',
	lazy          => 1,
	default       => '-',
	documentation => 'root directory where POD files are rendered',
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


=method is_indexable_file RELATIVE_PATH

[% ss.name %] tests whether a file at a RELATIVE_PATH is eligible to
be documented.  Currently only ".pm" files are eligible.

=example is_indexable_file()

=cut

sub is_indexable_file {
	my ($self, $qualified_path) = @_;
	return unless $qualified_path =~ /\.pm$/;
	return 1;
}


=method collect_files

[% ss.name %] collects files that are eligible for documenting.  It
uses File::Find to descend into directories in the "lib" directories.
Each file that is_indexable_file() approves is added to the library
for later processing.

=example collect_files()

=cut

sub collect_files {
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


=method index_library

[% ss.name %] invokes the Pod::Plexus library to index entities and
their corresponding documentation.  It is a prelude to dereferencing
entities and rendering their documentation.

=example index_library()

=cut

sub index_library {
	my $self = shift();
	$self->_library()->index();
	return 0;
}


=method render_library

[% ss.name %] renders every reqested document in the library.

=cut

sub render_library {
	my $self = shift();

	MODULE: foreach my $module_name (@{$self->module()}) {

		my $module = $self->_library()->get_document($module_name);
		unless ($module) {
			warn "Couldn't find and render $module.  Skipping...\n";
			next MODULE;
		}

		# TODO - Write out a file, if needed.

		my $output = $module->render();
		print $output, "\n";
	}

	return 0;
}


=method run

[% ss.name %] runs the Pod::Plexus command-line interface.  All
runtime parameters are taken from [% mod.package %] public attributes.
Thanks to MooseX::Getopt, those attributes are automatically populated
from corresponding command line arguments.

=example run()

=cut

sub run {
	my $self = shift();

	# Collect files from the libraries.
	# This minimally processes the files.

	$self->collect_files();

	my @errors;

	# This is a parsing, collection and error checking pass.
	# Cross-references aren't resolved.  Nothing is rendered yet.

	MODULE: foreach my $module_name (@{$self->module()}) {
		my $doc_object = $self->_library()->get_document($module_name);

		unless ($doc_object) {
			push @errors, "Can't find $module_name in library.";
			next MODULE;
		}

		$doc_object->collect_data(\@errors);
	}

	if (@errors) {
		warn "$_\n" foreach @errors;
		exit 1;
	}

	# This pass tries to find and inspect external referents.

	PASS: for (1..5) {
		my (@referents) = $self->_library()->get_unresolved_referents();
		last PASS unless @referents;

		foreach my $referent (@referents) {
			warn "   $referent";
			$self->_library()->add_module($referent);
		}
	}

	my (@referents) = sort $self->_library()->get_unresolved_referents();
	if (@referents) {
		push @errors, "Can't find some modules: @referents";
	}

	if (@errors) {
		warn "$_\n" foreach @errors;
		exit 1;
	}

	# TODO NEXT - After all external references are loaded, begin
	# derefereincing somehow.

	MODULE: foreach my $module_name (@{$self->module()}) {
		my $doc_object = $self->_library()->get_document($module_name);

		unless ($doc_object) {
			push @errors, "Can't find $module_name in library.";
			next MODULE;
		}

		$doc_object->dereference(\@errors);
	}

	if (@errors) {
		warn "$_\n" foreach @errors;
		exit 1;
	}

	# Render the requested documents.

	MODULE: foreach my $module_name (@{$self->module()}) {
		my $doc_object = $self->_library()->get_document($module_name);

		# TODO - Render to files, if appropriate.
		print $doc_object->render(), "\n\n--------------------------------\n\n";
	}

	# TODO - Render to files, if appropriate.

	#my $index = $library->generate_index();
	#my $toc = $library->generate_toc();
}

no Moose;

1;
