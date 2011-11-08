package Pod::Plexus::Distribution;

use Moose;
use Template;
use Carp qw(confess croak);
use Module::Util qw(find_installed);

use Pod::Plexus::Module;


=attribute modules_by_file

[% ss.name %] references a hash of [% lib.main %]::Module objects
keyed on each module's file path.  Paths are relative to the
distribution's root directory.

Modules use this attribute to find other module by their relative
paths.

Dealing with multiple modules in a single file is a challenge that
hasn't yet been met.

=cut

=method _add_module_by_file

Associate a MODULE_OBJECT with the FILE_PATH from which it was
parsed.  Don't use this directly.  Instead, use the public add_file()
method, which handles cross references between files and modules.

=cut

=method _get_module_by_file

Retrieve a [% lib.main %]::Module from the distribution by its
FILE_PATH relative to the distribution's root directory.

=cut

=method has_module_by_file

[% ss.name %] determines whether the distribution contains a module
for the given FILE_PATH.

=cut

has modules_by_file => (
	is      => 'rw',
	isa     => 'HashRef[Pod::Plexus::Module]',
	default => sub { { } },
	traits  => [ 'Hash' ],
	handles => {
		_add_module_by_file => 'set',
		_get_module_by_file => 'get',
		has_module_by_file  => 'exists',
	},
);


=attribute modules_by_package

[% ss.name %] holds a hash of [% lib.main %]::Module objects keyed
on their main package names.  For [% lib.main %]'s purposes, the main
package is defined by the first C<package> statement in the module.

=cut

=method get_known_module_objects

[% ss.name %] returns a list of known module objects.

=cut

=method get_known_module_names

[% ss.name %] returns a list of known module package names.

=cut

has modules_by_package => (
	is      => 'rw',
	isa     => 'HashRef[Pod::Plexus::Module]',
	default => sub { { } },
	traits  => [ 'Hash' ],
	handles => {
		_has_module_by_package      => 'exists',
		_add_module_by_package      => 'set',
		_get_module_by_package      => 'get',
		get_known_module_names            => 'keys',
		get_known_module_objects    => 'values',
	},
);


has verbose => (
	is      => 'rw',
	isa     => 'Bool',
	default => 0,
);


=method add_file

Add a file to the distribution.  A [% lib.main %]::Module is built
from the contents of the file at the relative FILE_PATH and added to
the distribution.  The get_module() accessor will retrieve the module
object by either its relative FILE_PATH or its main package name.

=cut

sub add_file {
	my ($self, $file_path) = @_;

	my $module = Pod::Plexus::Module->new(
		pathname     => $file_path,
		distribution => $self,
		verbose      => $self->verbose(),
	);

	$self->_add_module_by_file($file_path => $module);
	$self->_add_module_by_package($module->package() => $module);

	undef;
}


=method add_module

[% ss.name %] adds a module by its MODULE_NAME.  It looks up the full
path to the module, and then it calls add_file() to add that file.

=cut

sub add_module {
	my ($self, $module_name) = @_;

	my $path = find_installed($module_name);
	croak "Can't find $module_name name" unless defined $path and length $path;

	$self->add_file($path);
}


=method get_module

[% ss.name %] returns a [% lib.main %]::Module that matches a given
MODULE_IDENTIFIER, or undef if no module matches.  The module
identifier may be a file's relative path in the distribution or its
main module name.  [% ss.name %] will determine which based on
MODULE_INDENTIFIER's syntax.

=cut

sub get_module {
	my ($self, $module_key) = @_;

	if ($module_key =~ /^[\w:']+$/) {
		return unless $self->_has_module_by_package($module_key);
		return $self->_get_module_by_package($module_key);
	}

	return unless $self->has_module_by_file($module_key);
	return $self->_get_module_by_file($module_key);
}


=method index

[% ss.name %] indexes the distribution.  Methods and attributes are
identified and inspected.  Documantation is pulled apart and
associated with implementation.  Some documentation is generated, when
possible and reasonable.  Errors are thrown for undocumented things.

=cut

sub index {
	my $self = shift();
	$_->index() foreach $self->get_known_module_objects();
}


=method get_unresolved_referents

[% ss.name %] collects and returns the unique referents across all
known modules.

=cut

sub get_unresolved_referents {
	my $self = shift();

	my %referents;

	MODULE: foreach my $module ($self->get_known_module_objects()) {
		my @referents = $module->get_referents();
		REFERENT: while (@referents) {
			my $referent = shift @referents;

			if (ref($referent) eq 'Regexp') {
				push @referents, (grep /$referent/, $self->get_known_module_names());
				next REFERENT;
			}

			next REFERENT if $self->_has_module($referent);
			$referents{$referent} = 1;
		}
	}

	return keys %referents;
}


no Moose;

1;

=abstract Represent a distribution containing zero or more [% lib.main %] modules.

=cut
