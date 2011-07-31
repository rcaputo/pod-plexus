package Pod::Plexus::Cli;

use Moose;
with 'MooseX::Getopt';

use Pod::Plexus::Library;
use File::Find;

=method new_with_options

[% ss.name %] constructs one new [% mod.package %] object, using
values from the command line to populate constructor parameters.
See L</PUBLIC ATTRIBUTES> for constructor options and the command line
switches that populate them.

=skip attribute usage

=skip attribute ARGV

=skip attribute extra_argv

=skip attribute help_flag

=skip method process_argv

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

	return 0;
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

=method dereference_library

[% ss.name %] is a simple helper method to resolve resolves code and
documentation references within the library:

=example dereference_library()

=cut

sub dereference_library {
	my $self = shift();
	$self->_library()->dereference();
	return 0;
}

=method render_library

[% ss.name %] renders every reqested document in the library.

=cut

sub render_library {
	my $self = shift();
	warn "render_library()... not yet";  # TODO
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

	return(
		$self->collect_files()       ||
		$self->index_library()       ||
		$self->dereference_library() ||
		$self->render_library()      ||
		0
	);
}

no Moose;

1;

__END__

=abstract The Pod::Plexus command line utility implementation.

=cut