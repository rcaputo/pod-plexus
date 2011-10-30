package Pod::Plexus::Docs;

# TODO - render() -> as_pod_elements()
# TODO - Nested Pod::Elemental bits.
# TODO - Proper cloning of copied bits so they may be written.

sub as_pod_elements {
	my $self = shift();
	return text_paragraph("!!! $self\n");
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


sub _is_terminal_element {
	my ($self, $element) = @_;

	if ($element->isa('Pod::Elemental::Element::Generic::Command')) {

		my $command = $element->{command};

		# "=cut" is consumed.

		if ($command eq 'cut') {
			$self->push_cut();
			$self->is_terminated(1);
			return(1, 1);
		}

		# Other terminal top-level commands aren't consumed.
		# These are POD stuff that Pod::Plexus doesn't know about.
		# They do however imply "=cut".

		if ($command =~ /^head\d$/) {
			$self->push_cut();
			$self->is_terminated(1);
			return(1, 0);
		}

		return(0, 0);
	}

	# Other entities terminate this one.

	if ($element->isa('Pod::Plexus::Docs') and $element->is_terminal()) {
		$self->push_cut();
		$self->is_terminated(1);
		return(1, 0);
	}

	return(0, 0);
}


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
		return $self->calc_key(ref($self), $self->module_package(), $self->symbol());
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


=attribute definition_package

[% ss.name %] contains the package the reference was invoked in.

=cut

has definition_package => (
	default => sub { my $self = shift(); $self->module_package(); },
	is      => 'ro',
	isa     => 'Str',
	lazy    => 1,
);


=attribute definition_file

[% ss.name %] contains the path of the file invoking this reference.

=cut

has definition_file => (
	default => sub { my $self = shift(); $self->module_path(); },
	is      => 'ro',
	isa     => 'Str',
	lazy    => 1,
);


=attribute definition_line

[% ss.name %] contains the line number of this reference's invocation.

=cut

has definition_line => (
	default => sub { my $self = shift(); $self->node()->{start_line}; },
	is      => 'ro',
	isa     => 'Int',
	lazy    => 1,
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
	return $self->definition_package() eq $self->module_package();
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
	handles  => {
		module_package => 'package',
		module_path => 'pathname',
	},
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
