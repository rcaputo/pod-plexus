package Pod::Plexus::Docs::Abstract;

=abstract Remember and render cross-references.

=cut

use Moose;
extends 'Pod::Plexus::Docs';


use constant POD_COMMAND  => 'abstract';


has '+symbol' => (
	default => sub { "" },
);


has '+is_terminal' => (
	default => 1,
);


has abstract => (
	default => sub { shift()->node()->{content} },
	is      => 'ro',
	isa     => 'Str',
	lazy    => 1,
);


sub BUILD {
	my $self = shift();

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


sub consume_element {
	my ($self, $element) = @_;

	return 0 if $self->is_terminated();

	if ($element->isa('Pod::Elemental::Element::Generic::Command')) {

		my $command = $element->{command};

		# "=cut" is consumed.

		if ($command eq 'cut') {
			$self->push_cut();
			$self->is_terminated(1);
			return 1;
		}

		# Other terminal top-level commands aren't consumed.
		# They do however imply "=cut".

		if ($command =~ /^head\d$/) {
			$self->push_cut();
			$self->is_terminated(1);
			return 0;
		}
	}

	# Other entities terminate this one.

	if ($element->isa('Pod::Plexus::Docs::Code')) {
		$self->push_cut();
		$self->is_terminal(1);
		return 0;
	}

	# Otherwise, discard the documentation.

	return 1 if $element->isa('Pod::Elemental::Element::Generic::Blank');

	$element->{content} =~ s/^/Illegal content in =abstract: /;
	$self->push_documentation($element);
	return 1;
}


no Moose;

1;
