package Pod::Plexus::Entity;

use Moose;

use Carp qw(confess);

=attribute name

[% ss.name %] contains this Pod::Plexus documentable entity's name.

=cut

has name => (
	is       => 'ro',
	isa      => 'Str',
	required => 1,
);

=attribute private

[% ss.name %] is a read-only accessor that tells whether the entity is
public or private.  By default, entities with names beginning with one
or more underscores are considered private.  All others are considered
public.

=cut

has private => (
	is      => 'ro',
	isa     => 'Bool',
	lazy    => 1,
	default => sub { (shift()->name() =~ /^_/) || 0 },
);

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

=attribute mop_entity

[% ss.name %] contains the Class::MOP object representing this entity
in Moose.  It's added by Pod::Plexus::Document during its indexing
phase.

=cut

has mop_entity => (
	is       => 'ro',
	isa      => 'Undef',
	required => 1,
);

no Moose;

1;

__END__

=abstract A basic documentable entity.

=method new

Constructs one [% mod.package %] object.  See L</PUBLIC ATTRIBUTES>
for constructor options.

=cut
