package Pod::Plexus::Entity::Method;

use Moose;
extends 'Pod::Plexus::Entity';

has mop_entity => (
	is       => 'ro',
	isa      => 'Class::MOP::Method',
	required => 1,
);

no Moose;

1;

__END__

=abstract A documentable method.

=cut
