package Pod::Plexus::Docs;

# TODO - render() -> as_pod_elements()
# TODO - Nested Pod::Elemental bits.
# TODO - Proper cloning of copied bits so they may be written.

sub as_pod_elements {
	my $self = shift();

	return Pod::Elemental::Element::Generic::Text->new(
		content => "!!! $self",
	);
}

=abstract A generic expandable documentation reference.

=cut

=head1 SUBCLASSES

=index 2 ^Pod::Plexus::Docs::

=cut

use Moose;
with 'Pod::Plexus::Role::Documentable';

use Carp qw(croak);

has is_terminal => (
	is      => 'ro',
	isa     => 'Bool',
	default => 0,
);

=method consume_element

[% ss.name %] is called for the Pod::Elemental elements immediately
following the one that caused this reference to be created.  While
those trailing elements belong to this one, they should be added to
this reference's documentation.  [% ss.name %] returns true for as
long as the elements are part of this reference.  The parser will stop
looking for new documentation after the first false return value.

[% mod.name %] implements the base method to do nothing and return
false immediately.

=cut

sub consume_element {
	my ($self, $element) = @_;
	return 0;
}


sub _build_documentation {
	return [ ];
}


=attribute key

[% ss.name %] contains a reference's unique identifying key.  It calls
calc_key() to calculate it, then caches it for faster use later.

=cut

has key => (
	is      => 'ro',
	isa     => 'Str',
	lazy    => 1,
	default => sub {
		my $self = shift();
		return $self->calc_key(ref($self), $self->module(), $self->symbol());
	},
);


=method calc_key

[% ss.name %] calculates a reference's unique key from three
parameters: the reference's class name, the reference's module name,
and an optional symbol within the module.  Omit the symbol to
reference the module as a whole.

[% ss.name %] may be called as a class or object method.  If the
caller has the object but not all the necessary parameters, it may be
more convenient to access the key() attribute instead.

=cut

sub calc_key {
	(undef, my ($type, $module, $symbol)) = @_;
	$symbol //= "";
	return join("\t", $type, $module, ($symbol // ""));
}


=attribute invoked_in

[% ss.name %] contains the package the reference was invoked in.

=cut

has invoked_in => (
	default => sub { my $self = shift(); $self->module()->package(); },
	is      => 'ro',
	isa     => 'Str',
	lazy    => 1,
);


=attribute invoke_path

[% ss.name %] contains the path of the file invoking this reference.

=cut

has invoke_path => (
	default => sub { my $self = shift(); $self->module()->pathname(); },
	is      => 'ro',
	isa     => 'Str',
	lazy    => 1,
);


=attribute invoke_line

[% ss.name %] contains the line number of this reference's invocation.

=cut

has invoke_line => (
	default => sub { my $self = shift(); $self->node()->{start_line}; },
	is      => 'ro',
	isa     => 'Int',
	lazy    => 1,
);


=attribute module

[% ss.name %] contains the module being referenced.  This is required.

=cut

has module => (
	default  => sub { my $self = shift(); return $self->module()->package(); },
	is       => 'ro',
	isa      => 'Str|RegexpRef',
	lazy     => 1,
);


=attribute symbol

[% ss.name %] optinally references a particular symbol in the module
being referenced.  If omitted, the reference will apply to the target
module() as a whole.

=cut

has symbol => (
	default => sub {
		my $self = shift;
		confess "$self symbol's default must be overridden";
	},
	is      => 'rw',
	isa     => 'Str',
	lazy    => 1,
);


=method is_local

[% ss.name %] returns true if the reference is local within the module
invoking it.

=cut

sub is_local {
	my $self = shift();
	return $self->invoked_in() eq $self->module();
}


has distribution => (
	is       => 'ro',
	isa      => 'Pod::Plexus::Distribution',
	required => 1,
);


has module => (
	is       => 'ro',
	isa      => 'Pod::Plexus::Module',
	required => 1,
);


has errors => (
	is       => 'rw',
	isa      => 'ArrayRef',
	required => 1,
);


has node => (
	is       => 'ro',
	isa      => 'Pod::Elemental::Element::Generic::Command',
	required => 1,
);


sub resolve {
	# Virtual base method.  Does nothing by default.
}


sub create {
	my $class = shift();
	return $class->new(@_);
}

no Moose;

1;
