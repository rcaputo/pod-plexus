package Pod::Plexus::Entity::Attribute;

use Moose;
extends 'Pod::Plexus::Entity';

has mop_entity => (
	is       => 'ro',
	isa      => 'Class::MOP::Attribute',
	required => 1,
);

no Moose;

1;

__END__

=abstract A documentable class attribute.

=cut
