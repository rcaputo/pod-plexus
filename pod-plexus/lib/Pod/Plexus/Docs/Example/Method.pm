package Pod::Plexus::Docs::Example::Method;

=abstract A reference to a code example from a method.

=cut

use Moose;
extends 'Pod::Plexus::Docs::Example';

sub resolve {
	my $self = shift();

	my $foreign_doc_name = $self->module();
	my $foreign_doc      = $self->library()->get_document($foreign_doc_name);

	# TODO - Kinda iffy here to pass in our \@errors?
	# TODO - Seems like a half-change waiting for rectification.
	$foreign_doc->prepare_to_render($self->errors());
	return if @{$self->errors()};

	my $method_name = $self->symbol();
	my $code        = $self->beautify_code($foreign_doc->sub($method_name));

	my $link;
	if ($self->is_local()) {
		$link = "This is L<$method_name()|/$method_name>.\n\n";
	}
	else {
		$link = (
			"This is L<$foreign_doc_name|$foreign_doc_name> " .
			"sub L<$method_name()|$foreign_doc_name/$method_name>.\n\n"
		);
	}

	$self->set_example($link, $code);
}

no Moose;

1;
