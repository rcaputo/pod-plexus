package Pod::Plexus::Reference::Include;

use Moose;
extends 'Pod::Plexus::Reference';

sub dereference {
	my ($self, $library, $document, $errors) = @_;

	my $module_name = $self->module();
	my $module      = $library->get_document($module_name);
	my $pod_copy    = $module->pod_section($self->symbol());

	unless (@$pod_copy) {
		push @$errors, (
			$self->invoked_in() . " references unknown POD section $module_name/" .
			$self->symbol()
		);
		return;
	}

	$self->documentation($pod_copy);
}

no Moose;

1;
