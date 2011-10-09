package Pod::Plexus::Docs::Cross;

=abstract Remember and render cross-references.

=cut

use Moose;
extends 'Pod::Plexus::Docs';


use constant POD_COMMAND  => 'xref';


has '+symbol' => (
	default => sub {
		my $self = shift();
		return $self->module();
	},
);


has '+module' => (
	default => sub {
		my $self = shift();
		return($self->node()->{content} =~ /^\s* (\S.*?) \s*$/x);
	},
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
}


no Moose;

1;
