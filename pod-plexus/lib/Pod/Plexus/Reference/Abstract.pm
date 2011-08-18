package Pod::Plexus::Reference::Abstract;

=abstract Remember and render cross-references.

=cut

use Moose;
extends 'Pod::Plexus::Reference';

has '+symbol' => (
	isa      => 'Maybe[Str]',
	required => 0,
);

has abstract => (
	is       => 'ro',
	isa      => 'Str',
	required => 1,
);

use constant POD_COMMAND  => 'abstract';
use constant POD_PRIORITY => 1000;


sub new_from_elemental_command {
	my ($class, $library, $document, $errors, $node) = @_;

	my $reference = $class->new(
		invoked_in  => $document->package(),
		module      => $document->package(),
		abstract    => $node->{content},
		invoke_path => $document->pathname(),
		invoke_line => $node->{start_line},
	);

	return $reference;
}

sub dereference {
	my ($self, $library, $document, $errors) = @_;

	$self->documentation(
		[
			Pod::Elemental::Element::Generic::Command->new(
				command => "head1",
				content => "NAME\n",
			),
			Pod::Elemental::Element::Generic::Blank->new(content => "\n"),
			Pod::Elemental::Element::Generic::Text->new(
				content => $self->module() . " - " . $self->abstract()
			),
			Pod::Elemental::Element::Generic::Blank->new(content => "\n"),
		],
	);
}

sub expand {
	my ($class, $document, $errors, $node) = @_;

	my $reference = $document->get_reference($class);

	unless ($reference) {
		push @$errors, (
			"Can't find reference for =abstract" .
			" at " . $document->pathname() . " line $node->{start_line}"
		);
	}

	return $reference;
}

no Moose;

1;
