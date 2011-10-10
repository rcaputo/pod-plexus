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
	my ($self, $document) = @_;

	my $package_name = $document->package();
	my $method_name  = $self->name();

	my $docs = $document->get_reference(
		'Pod::Plexus::Docs::Code::Method',
		$package_name,
		$method_name,
	);

	return 1 if $docs;
	return;
}


sub validate {
	my ($self, $document, $errors) = @_;

	return if $self->is_documented($document);

	push @$errors, (
		$document->package() .
		" method " . $self->name() .
		" is not documented"
	);
}


no Moose;

1;

__END__

=abstract A documentable method.

=cut
