package Pod::Plexus::Entity::Method;

use Moose;
extends 'Pod::Plexus::Entity';

=attribute meta_entity

=include Pod::Plexus::Entity meta_entity

=cut

has '+meta_entity' => (
	isa => 'Class::MOP::Method',
);

no Moose;

1;

__END__

=abstract A documentable method.

=cut
