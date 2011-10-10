package Pod::Plexus::Docs::Example::Module;

=abstract A reference to a code example from an entire module.

=cut

use Moose;
extends 'Pod::Plexus::Docs::Example';

sub dereference {
	my ($self, $library, $document, $errors) = @_;

	my $module_name = $self->module();
	my $module      = $library->get_document($module_name);
	my $code        = $self->beautify_code($module->code());

	my $link;

	# I hope it's not necessary to explain where it came from if it
	# contains a package statement.

	if ($code =~ /^\s*package/) {
		$link = "";
	}
	else {
		$link = "This is L<$module_name|$module_name>.\n\n";
	}

	$self->set_example($link, $code);
}

no Moose;

1;