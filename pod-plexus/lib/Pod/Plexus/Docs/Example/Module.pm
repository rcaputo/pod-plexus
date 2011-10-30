package Pod::Plexus::Docs::Example::Module;

=abstract A reference to a code example from an entire module.

=cut

use Moose;
extends 'Pod::Plexus::Docs::example';

sub dereference {
	my ($self, $distribution, $module, $errors) = @_;

	my $module_name  = $self->module_package();
	my $other_module = $distribution->get_module($module_name);
	my $code         = $self->beautify_code($other_module->code());

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
