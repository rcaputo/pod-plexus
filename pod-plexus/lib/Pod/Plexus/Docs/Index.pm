package Pod::Plexus::Docs::Index;

=abstract A reference to a dynamically generated module index.

=cut

use Moose;
extends 'Pod::Plexus::Docs';


has '+symbol' => (
	default => "",
);


use constant POD_COMMAND => 'index';


sub BUILD {
	my $self = shift();

	my ($header_level, $regexp) = $self->_parse_content();

	return unless $regexp;

	my @referents = sort grep /$regexp/, $self->distribution()->get_module_names();

	unless (@referents) {
		push @{$self->errors()}, (
			"=index $regexp ... doesn't match anything" .
			" at " . $self->module()->pathname() .
			" line " . $self->node()->{start_line}
		);
		return;
	}

	$self->push_documentation(
		map {
			my $foreign_module = $self->distribution()->get_module($_);

			$foreign_module->prepare_to_render($self->errors());
			return if @{$self->errors()};

			my $abstract = $self->distribution()->get_module($_)->abstract();
			$abstract = "No abstract defined." unless (
				defined $abstract and length $abstract
			);

			Pod::Elemental::Element::Generic::Command->new(
				command => "head" . $header_level,
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

	$element->{content} =~ s/^/Illegal content in =index: /;
	$self->push_documentation($element);
	return 1;
}


sub _parse_content {
	my $self = shift();

	my $regexp = $self->node()->{content};

	my $header_level = (
		($regexp =~ s/^\s*(\d+)\s*//)
		? $1
		: 2
	);

	$regexp =~ s/\s+//g;

	unless (length $regexp) {
		push @{$self->errors()}, (
			"=" . $self->node()->{command} . " command needs a regexp" .
			" at " . $self->module()->pathname() .
			" line " . $self->node()->{start_line}
		);
		return;
	}

	return( $header_level, qr/$regexp/ );
}


no Moose;

1;
