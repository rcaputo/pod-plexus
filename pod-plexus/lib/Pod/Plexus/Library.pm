package Pod::Plexus::Library;

use Moose;
use File::Find;
use Template;
use Carp qw(confess);

use Pod::Plexus::Document;

=doc documents

[% ss.name %] references a hash of [% lib.main_module %]::Document
objects, each of which is keyed on its file's path.  Paths are
relative to the distribution's root directory.

Documents use this attribute to find other documents by their relative
paths.

=doc _add_document FILE_PATH, DOCUMENT_OBJECT

Associate a DOCUMENT_OBJECT with the FILE_PATH from which it was
parsed.  Don't use this.  Instead, use the public add_file() method,
which is is the recommended way to add new files to [% module.name %].

Provided by Moose::Meta::Method::Accessor::Native::Hash.

=doc get_document

Retrieve a Pod::Plexus::Document from the library by its path relative
to the distribution's root directory.

Provided by Moose::Meta::Method::Accessor::Native::Hash.

=doc has_document FILE_PATH

Tests whether the library contains a document for the given FILE_PATH.

Provided by Moose::Meta::Method::Accessor::Native::Hash.

=cut

has documents => (
	is      => 'rw',
	isa     => 'HashRef[Pod::Plexus::Document]',
	default => sub { { } },
	traits  => [ 'Hash' ],
	handles => {
		_add_document => 'set',
		_get_document => 'get',
		has_document  => 'exists',
	},
);

=doc modules

[% this.name %] holds a hash of Pod::Plexus::Document objects, each

=cut

has modules => (
	is      => 'rw',
	isa     => 'HashRef[Pod::Plexus::Document]',
	default => sub { { } },
	traits  => [ 'Hash' ],
	handles => {
		has_module => 'exists',
		_add_module => 'set',
		get_module => 'get',
		get_module_names => 'keys',
	},
);

=doc _template

[% doc.module %] collects Pod::Plexus::Document objects in the hash
referenced by this attribute.  Documents are keyed on their primary
module name---the first package() statement in the file.

=doc has_module MODULE_PACKAGE

Test whether MODULE_NAME exists in the library.
Provided by Moose::Meta::Method::Accessor::Native::Hash.

=doc get_document

=cut

has _template => (
	is      => 'ro',
	isa     => 'Template',
	lazy    => 1,
	default => sub { Template->new() },
);

=for method module

=cut

sub module {
	my ($self, $module) = @_;

	confess "module $module doesn't exist" unless $self->has_module($module);
	return $self->get_module($module);
}

sub add_files {
	my ($self, $filter, @roots) = @_;

	find(
		{
			wanted => sub {
				return if $self->has_document($_) or not $filter->($_);

				$self->add_file($_);
			},
			no_chdir => 1,
		},
		@roots,
	);
}

sub add_file {
	my ($self, $file_path) = @_;

	my $document = Pod::Plexus::Document->new(
		pathname  => $file_path,
		library   => $self,
		_template => $self->_template(),
	);

	$document->collect_data();
warn "--- ", $file_path;
warn $document->package();
	$self->_add_document($file_path => $document);
	$self->_add_module($document->package() => $document);

	undef;
}

no Moose;

1;

__END__

=pod

=abstract Represent a library of one or more Pod::Plexus documents.

=head1 SYNOPSIS

=cut
