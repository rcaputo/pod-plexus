package Pod::Plexus::Reference::Example::Method;

=abstract A reference to a code example from a method.

=cut

use Moose;
extends 'Pod::Plexus::Reference::Example';

sub dereference {
	my ($self, $library, $document, $errors) = @_;

	my $module_name = $self->module();
	my $module      = $library->get_document($module_name);
	my $method_name = $self->symbol();
	my $code        = $self->beautify_code($module->sub($method_name));

	my $link;
	if ($self->is_local()) {
		$link = "This is L<$method_name()|/$method_name>.\n\n";
	}
	else {
		$link = (
			"This is L<$module_name|$module_name> " .
			"sub L<$method_name()|$module_name/$method_name>.\n\n"
		);
	}

	$self->set_example($link, $code);
}

no Moose;

1;
