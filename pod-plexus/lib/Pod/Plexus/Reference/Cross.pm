package Pod::Plexus::Reference::Cross;

=abstract Remember and render cross-references.

=cut

use Moose;
extends 'Pod::Plexus::Reference';

has '+symbol' => (
	isa      => 'Maybe[Str]',
	required => 0,
);

sub dereference {
	my ($self, $library, $document, $errors) = @_;

	my $referent_name = $self->module();
	my $referent = $library->get_document($referent_name);

	$self->documentation(
		[
			Pod::Elemental::Element::Generic::Command->new(
				command => "item",
				content => "*\n",
			),
			Pod::Elemental::Element::Generic::Blank->new(
				content => "\n",
			),
			Pod::Elemental::Element::Generic::Text->new(
				content => (
					"L<$referent_name|$referent_name> - " . $referent->abstract()
				),
			),
			Pod::Elemental::Element::Generic::Blank->new(
				content => "\n",
			),
		],
	);

	warn $self->dump();
}

no Moose;

1;
