package Pod::Plexus::Entity::Attribute;

use Moose;
extends 'Pod::Plexus::Entity';

=attribute mop_entity

=include Pod::Plexus::Entity mop_entity

=cut

has '+mop_entity' => (
	isa => 'Class::MOP::Attribute',
);

no Moose;

1;

__END__

=abstract A documentable class attribute.

=cut
