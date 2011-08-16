package Pod::Plexus::Reference::Cross;

=abstract Remember and render cross-references.

=cut

use Moose;
extends 'Pod::Plexus::Reference';

has '+discards_command' => (
	default => 1,
);

has '+discards_text' => (
	default => 1,
);

has '+symbol' => (
	isa      => 'Maybe[Str]',
	required => 0,
);

use constant POD_COMMAND  => 'xref';
use constant POD_PRIORITY => 5000;

sub new_from_elemental_command {
	my ($class, $library, $document, $errors, $node) = @_;

	my ($module) = ($node->{content} =~ /^\s* (\S.*?) \s*$/x);

	my $reference = $class->new(
		invoked_in  => $document->package(),
		module      => $module,
		invoke_path => $document->pathname(),
		invoke_line => $node->{start_line},
	);

	return $reference;
}

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
