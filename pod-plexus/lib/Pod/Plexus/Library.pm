package Pod::Plexus::Library;

use Moose;
use Template;
use Carp qw(confess croak);
use Module::Util qw(find_installed);

use Pod::Plexus::Document;

=attribute files

[% ss.name %] references a hash of [% lib.main %]::Document objects
keyed on each document's file path.  Paths are relative to the
distribution's root directory.

Documents use this attribute to find other documents by their relative
paths.

=cut

=method _add_file FILE_PATH, DOCUMENT_OBJECT

Associate a DOCUMENT_OBJECT with the FILE_PATH from which it was
parsed.  Don't use this directly.  Instead, use the public add_file()
method, which handles cross references between files and modules.

=cut

=method _get_file FILE_PATH

Retrieve a [% lib.main %]::Document from the library by its FILE_PATH
relative to the distribution's root directory.

=cut

=method has_file FILE_PATH

[% ss.name %] determines whether the library contains a document for
the given FILE_PATH.

=cut

has files => (
	is      => 'rw',
	isa     => 'HashRef[Pod::Plexus::Document]',
	default => sub { { } },
	traits  => [ 'Hash' ],
	handles => {
		_add_file => 'set',
		_get_file => 'get',
		has_file => 'exists',
	},
);


=attribute modules

[% ss.name %] holds a hash of [% lib.main %]::Document objects keyed
on their main package names.  For [% lib.main %]'s purposes, the main
package is defined by the first C<package> statement in the module.

=cut

=method get_documents

[% ss.name %] returns the document objects in the library.

=cut

has modules => (
	is      => 'rw',
	isa     => 'HashRef[Pod::Plexus::Document]',
	default => sub { { } },
	traits  => [ 'Hash' ],
	handles => {
		_has_module => 'exists',
		_add_module => 'set',
		_get_module => 'get',
		_get_module_names => 'keys',
		get_documents => 'values',
	},
);


=attribute _template

[% ss.name %] holds a Template toolkit object that will be shared
among all documents and PDO sections that are rendered.  It's used to
expand symbols such as section names, module names, and the library's
main module name.  This allows documentation to include names by
reference, so refactoring and renaming require fewer documentation
changes.

=cut

has _template => (
	is      => 'ro',
	isa     => 'Template',
	lazy    => 1,
	default => sub { Template->new() },
);


=method add_file FILE_PATH

Add a file to the library.  A [% lib.main %]::Document is built from
the contents of the file at the relative FILE_PATH, and it's added to
the library.  The document may be retrieved from the library by its
relative FILE_PATH or its main module name using the get_document()
accessor.

=cut

sub add_file {
	my ($self, $file_path) = @_;

	my $document = Pod::Plexus::Document->new(
		pathname  => $file_path,
		library   => $self,
		_template => $self->_template(),
	);

	$self->_add_file($file_path => $document);
	$self->_add_module($document->package() => $document);

	undef;
}


=method add_module MODULE_NAME

[% ss.name %] adds a module by its MODULE_NAME.  It looks up the full
path to the module and adds that.

=cut

sub add_module {
	my ($self, $module_name) = @_;

	my $path = find_installed($module_name);
	croak "Can't find $module_name name" unless defined $path and length $path;

	$self->add_file($path);
}


=method get_document DOCUMENT_REFERENCE

[% ss.name %] returns a [% lib.main %]::Document that matches a given
DOCUMENT_REFERENCE, or undef if no document matched.  The document
reference may be a file's relative path in the library or its main
module name.  [% ss.name %] will determine which based on
DOCUMENT_REFERENCE's syntax.

=cut

sub get_document {
	my ($self, $document_key) = @_;

	if ($document_key =~ /^[\w:']+$/) {
		return unless $self->_has_module($document_key);
		return $self->_get_module($document_key);
	}

	return unless $self->has_file($document_key);
	return $self->_get_file($document_key);
}


=method index

[% ss.name %] indexes the library.  Methods and attributes are
identified and inspected.  Documantation is pulled apart and
associated with implementation.  Some documentation is generated, when
possible and reasonable.  Errors are thrown for undocumented things.

=cut

sub index {
	my $self = shift();
	$_->index() foreach $self->get_documents();
}


=method dereference

Resolve references to other code and documentation entities.  Tell
documents to import the things they reference into the places where
they're referenced.  This should be done before variable expansion,
since the values of those variables depend upon the location where
they're resolved.

=cut

sub dereference {
	my $self = shift();

	my @pending = $self->get_documents();

	$_->dereference_immutables() foreach @pending;

	my $remaining_attempts = 5;

	ATTEMPT: while (@pending and $remaining_attempts--) {
		my @next_pending;
		my @errors;

		PENDING: foreach my $next (@pending) {
			my @unreferenced = $next->dereference_mutables();
			if (@unreferenced) {
				push @next_pending, $next;
				push @errors, [ $next, \@unreferenced ];
				next PENDING;
			}
		}

		last ATTEMPT unless @errors;

		if ($remaining_attempts) {
			@pending = @next_pending;
			next ATTEMPT;
		}

		# Tried too many times.  What failed?

		warn "Couldn't resolve these symbols:\n";
		foreach my $error (@errors) {
			my ($module, $symbols) = @$error;
			warn "  ", $module->package(), " - ", join(", ", @$symbols), "\n";
		}

		exit 1;
	}
}


=method get_unresolved_referents

[% ss.name %] collects and returns the unique referents across all
known documents.

=cut

sub get_unresolved_referents {
	my $self = shift();

	my %referents;

	DOCUMENT: foreach my $document ($self->get_documents()) {
		REFERENT: foreach ($document->get_referents()) {
			next REFERENT if $self->_has_module($_);
			$referents{$_} = 1;
		}
	}

	return keys %referents;
}


no Moose;

1;

=abstract Represent a library of one or more [% lib.main %] documents.

=cut
