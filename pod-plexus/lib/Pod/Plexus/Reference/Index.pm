package Pod::Plexus::Reference::Index;

use Moose;
extends 'Pod::Plexus::Reference';

has '+symbol' => (
	required => 0,
);

has header_level => (
	is       => 'ro',
	isa      => 'Num',
	required => 1,
);

sub dereference {
	my ($self, $library, $document, $errors) = @_;

	my $referent_regexp = $self->module();

	my @referents = sort grep /$referent_regexp/, $library->get_module_names();

	unless (@referents) {
		push @$errors, (
			"=index $referent_regexp ... doesn't match anything" .
			" at " . $self->invoke_path() . " line " . $self->invoke_line
		);
		return;
	}

	$self->documentation(
		[
			map {
				my $foreign_document = $library->get_document($_);

				$foreign_document->collect_data($errors);

				my $abstract = $library->get_document($_)->abstract();
				$abstract = "No abstract defined." unless (
					defined $abstract and length $abstract
				);

				Pod::Elemental::Element::Generic::Command->new(
					command => "head" . $self->header_level(),
					content => "\n",
				),
				Pod::Elemental::Element::Generic::Blank->new(
					content => "\n",
				),
				Pod::Elemental::Element::Generic::Text->new(
					content => "L<$_|$_> - $abstract\n",
				),
				Pod::Elemental::Element::Generic::Blank->new(
					content => "\n",
				),
			}
			@referents
		]
	);
}

no Moose;

1;
