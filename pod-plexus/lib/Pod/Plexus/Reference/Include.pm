package Pod::Plexus::Reference::Include;

=abstract A reference to documentation included from elsewhere.

=cut

use Moose;
extends 'Pod::Plexus::Reference';

use constant POD_COMMAND  => 'include';
use constant POD_PRIORITY => 5000;

sub new_from_elemental_command {
	my ($class, $library, $document, $errors, $node) = @_;

	# Parse the content into a module and POD entry name to include.

	my ($module, $symbol) = $class->_parse_include_spec(
		$document, $errors, $node
	);

	return unless $module;

	my $reference = $class->new(
		invoked_in  => $document->package(),
		module      => $module,
		symbol      => $symbol,
		invoke_path => $document->pathname(),
		invoke_line => $node->{start_line},
	);

	return $reference;
}

sub dereference {
	my ($self, $library, $document, $errors) = @_;

	my $module_name = $self->module();
	my $module      = $library->get_document($module_name);
	my $pod_copy    = [ ]; # $module->pod_section($self->symbol());

#	unless (@$pod_copy) {
#		push @$errors, (
#			$self->invoked_in() . " includes unknown POD section $module_name/" .
#			$self->symbol()
#		);
#		return;
#	}

	$self->documentation($pod_copy);
}

sub expand {
	my ($class, $document, $errors, $node) = @_;

	my ($module, $symbol) = $class->_parse_include_spec(
		$document, $errors, $node
	);

	return $document->get_reference($class, $module, $symbol);
}

sub _parse_include_spec {
	my ($class, $document, $errors, $node) = @_;

	if ($node->{content} =~ m!^\s* (\S*) \s+ (\S.*?) \s*$!x) {
		return($1, $2);
	}

	if ($node->{content} =~ m!^\s* (\S*) \s*$!x) {
		return($document->package(), $1);
	}

	push @$errors, (
		"Wrong inclusion syntax: =include $node->{content}" .
		" at " . $document->pathname() . " line $node->{start_line}"
	);

	return;
}

no Moose;

1;
