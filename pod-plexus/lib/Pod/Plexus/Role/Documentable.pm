package Pod::Plexus::Role::Documentable;

use Moose::Role;

=attribute documentation

[% ss.name %] contains the Pod::Plexus documentation associated with
this code entity.

=cut

=method is_dereferenced

[% ss.name %] returns a Boolean value indicating whether this code
entity has associated documentation.

=cut

=method push_documentation POD_ELEMENTAL_PARAGRAPHS

[% ss.name %] pushes one or more Pod::Elemental::Paragraph objects
onto this entity's documentation.  Paragraphs may be commands, text,
blank lines, and anything else Pod::Elemental supports.

=cut

has documentation => (
	is      => 'rw',
	isa     => 'ArrayRef[Pod::Elemental::Paragraph]',
	traits  => [ 'Array' ],
	default => sub { [ ] },
	handles => {
		is_dereferenced    => 'count',
		push_documentation => 'push',
	},
);

=attribute _is_resolved

[% ss.name %] describes whether the documentation for the object that
consumes this role has had its templates resolved.  It may not be true
until the consumer is also documented.

=cut

has _is_resolved => (
	is      => 'rw',
	isa     => 'Bool',
	default => 0,
);

=method is_resolved

[% ss.name %] returns true if the object consuming this role has
documentation that has had its templates resolved.

=cut

sub is_resolved {
	my $self = shift();
	return $self->is_dereferenced() && $self->_is_resolved();
}

no Moose::Role;

1;
