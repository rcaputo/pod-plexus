package Pod::Plexus::Docs::abstract;

=abstract Remember and render cross-references.

=cut

use Moose;
extends 'Pod::Plexus::Docs';

use Pod::Plexus::Util::PodElemental qw(
	blank_line head_paragraph text_paragraph
);


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
			head_paragraph(1, "NAME\n"),
			blank_line(),
			text_paragraph($self->module_package() . " - " . $self->abstract()),
			blank_line(),
		],
	);
}


sub consume_element {
	my ($self, $element) = @_;

	return 0 if $self->is_terminated();

	my ($is_terminated, $is_consumed) = $self->_is_terminal_element(
		$self, $element
	);

	return $is_consumed if $is_terminated;

	# Otherwise, discard the documentation.

	return 1 if $element->isa('Pod::Elemental::Element::Generic::Blank');

	$element->{content} =~ s/^/Illegal content in =abstract: /;
	$self->push_documentation($element);
	return 1;
}


no Moose;

1;
