package Pod::Plexus::Code::Attribute;

use Moose;
extends 'Pod::Plexus::Code';

=attribute meta_entity

=include Pod::Plexus::Code attribute meta_entity

=cut

use Moose::Util::TypeConstraints qw(class_type);

class_type('Class::MOP::Attribute');
class_type('Moose::Meta::Role::Attribute');

has '+meta_entity' => (
	isa => 'Class::MOP::Attribute | Moose::Meta::Role::Attribute',
);

no Moose;

1;

__END__

=abstract A documentable class attribute.

=cut
