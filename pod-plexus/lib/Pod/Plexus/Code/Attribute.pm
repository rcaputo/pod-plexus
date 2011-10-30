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


sub is_documented {
	my ($self, $module) = @_;

	my $package_name   = $module->package();
	my $attribute_name = $self->name();

	my $docs = $module->get_reference(
		'Pod::Plexus::Docs::Code::Attribute',
		$package_name,
		$attribute_name,
	);

	return 1 if $docs;
	return;
}


sub validate {
	my ($self, $module, $errors) = @_;

	return if $self->is_documented($module);

	push @$errors, (
		$module->package() .
		" attribute " . $self->name() .
		" is not documented"
	);
}


no Moose;

1;

__END__

=abstract A documentable class attribute.

=cut
