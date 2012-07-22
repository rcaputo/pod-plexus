package Pod::Plexus::Distribution;
# TODO - Edit pass 1 done.

use Moose;
use Template;
use Carp qw(confess croak);
use Module::Util qw(find_installed);

use Pod::Plexus::Module;
use Template::Stash;


=abstract Represent a distribution containing zero or more Pod::Pleuxs modules.

=cut


=head1 SYNOPSIS

=example Pod::Plexus::Cli attribute _distribution

=cut


=head1 DESCRIPTION

[% m.name %] represents an entire code distribution.  It contains zero
or more modules, each of which must contain documentation and code.

[% m.name %] provides attributes and methods to access and manipulate
modules and their documentation.

=cut


$Template::Stash::SCALAR_OPS->{call} = sub {
	my ($class, $method, @parameters) = @_;
	return $class->$method(@parameters);
};

$Template::Stash::SCALAR_OPS->{does} = sub {
	my ($class, $method) = @_;
	return $class->does($method);
};


=attribute template

"[% s.name %]" contains a template object that will be used to expand
variables and perhaps other things within the documentation.  It's a
Text::Template object by default.

=cut

has template => (
	is => 'ro',
	isa => 'Template',
	default => sub {
		return Template->new(
			{
				INTERPOLATE => 0,
				POST_CHOMP  => 0,
				PRE_CHOMP   => 0,
				STRICT      => 1,
				TRIM        => 0,
			}
		);
	},
);


=attribute modules_by_file

"[% s.name %]" maps relative module paths to their corresponding
Pod::Plexus::Module objects.  Paths are relative to the distribution's
root directory.

Modules use this attribute to find siblings by their relative paths.

This implementation restricts each module to hold a single class.
Multiple classes per module may be supported in the future.

=cut

=method _add_module_by_file

Associate a MODULE_OBJECT with the FILE_PATH from which it was
parsed.  Don't use this directly.  Instead, use the public add_file()
method, which handles cross references between files and modules.

=cut

=method _get_module_by_file

Retrieve a Pod::Plexus::Module from the distribution by its
FILE_PATH relative to the distribution's root directory.

=cut

=method has_module_by_file

[% s.name %] determines whether the distribution contains a module
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

[% s.name %] holds a hash of Pod::Plexus::Module objects keyed
on their main package names.  For Pod::Plexus's purposes, the main
package is defined by the first C<package> statement in the module.

=cut

=method get_known_module_objects

[% s.name %] returns a list of known module objects.

=cut

=method get_known_module_names

[% s.name %] returns a list of known module package names.

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


=inherits Pod::Plexus::Cli attribute blame

=cut

has blame => (
	is      => 'rw',
	isa     => 'Bool',
	default => 0,
);


=inherits Pod::Plexus::Cli attribute verbose

=cut

has verbose => (
	is      => 'rw',
	isa     => 'Bool',
	default => 0,
);


=method add_file

[% s.name $](MODULE_PATH) adds a file to the distribution.  A
Pod::Plexus::Module is built from the contents of the file at the
relative MODULE_PATH and added to the distribution.

The get_module() accessor will retrieve the module object by either
its relative MODULE_PATH or its main package name.

=cut

sub add_file {
	my ($self, $file_path) = @_;

	my $module = Pod::Plexus::Module->new(
		pathname     => $file_path,
		distribution => $self,
		verbose      => $self->verbose(),
		blame        => $self->blame(),
	);

	$self->_add_module_by_file($file_path => $module);
	$self->_add_module_by_package($module->package() => $module);

	undef;
}


=method add_module

[% s.name %] adds a module by its MODULE_NAME.  It looks up the full
path to the module, and then it calls add_file() to add that file.

=cut

sub add_module {
	my ($self, $module_name) = @_;

	my $path = find_installed($module_name);
	croak "Can't find $module_name name" unless defined $path and length $path;

	$self->add_file($path);
}


=method get_module

[% s.name %](RELATIVE_PATH) or [% s.name %](MAIN_PACKAGE) returns a
Pod::Plexus::Module object that matches a given RELATIVE_PATH or
MAIN_PACKAGE name.  It returns undef if the module is unknoqn.

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


no Moose;

1;
