package Pod::Plexus::Code::Method;

use Moose;
extends 'Pod::Plexus::Code';

=attribute meta_entity

=include Pod::Plexus::Code method meta_entity

=cut

has '+meta_entity' => (
	isa => 'Class::MOP::Method',
);


sub is_documented {
	my ($self, $module) = @_;

	my $package_name = $module->package();
	my $method_name  = $self->name();

	my $docs = $module->get_matter(
		'method',
		$method_name,
	);

	return 1 if $docs;
	return;
}


sub validate {
	my ($self, $module, $errors) = @_;

	return if $self->is_documented($module);

	push @$errors, (
		$module->package() .
		" method " . $self->name() .
		" is not documented"
	);
}


no Moose;

1;

__END__

=abstract A documentable method.

=cut
