package Pod::Plexus::Role::Documentable;

use Moose::Role;

=attribute documentation

[% ss.name %] contains the Pod::Plexus documentation associated with
this code entity.

=method is_documented

[% ss.name %] returns a Boolean value indicating whether this code
entity has associated documentation.

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
		is_documented => 'count',
		push_documentation => 'push',
	},
);

no Moose::Role;

1;
