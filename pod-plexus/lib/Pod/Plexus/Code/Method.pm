package Pod::Plexus::Code::Method;

use Moose;
extends 'Pod::Plexus::Code';

=attribute meta_entity

=include Pod::Plexus::Code attribute meta_entity

=cut

has '+meta_entity' => (
	isa => 'Class::MOP::Method',
);

no Moose;

1;

__END__

=abstract A documentable method.

=cut
