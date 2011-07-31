package Pod::Plexus::Entity::Method;

use Moose;
extends 'Pod::Plexus::Entity';

=attribute mop_entity

=include Pod::Plexus::Entity mop_entity

=cut

has '+mop_entity' => (
	isa => 'Class::MOP::Method',
);

no Moose;

1;

__END__

=abstract A documentable method.

=cut
