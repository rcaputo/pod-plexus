package Pod::Plexus::Matter::Reference;

# TODO - Edit pass 0 done.

=abstract An abstract section that references something else.

=cut

use Moose;
extends 'Pod::Plexus::Matter';
with 'Pod::Plexus::Matter::Role::HasNoBody';


has referent => (
	is       => 'rw',
	isa      => 'Pod::Plexus::Matter',
	weak_ref => 1,
);


sub get_referent_module {
	my ($self, $module_name) = @_;

	my $referent_module = $self->module_distribution()->get_module($module_name);
	return $referent_module if $referent_module;

	my $element = $self->element();
	chomp(my $content = $element->content());
	die [
		"Can't find module referred to" .
		" in '=" . $element->command() . " $content'" .
		" at " . $self->module_pathname() .
		" line " . $element->start_line()
	];
}


sub get_referent_matter {
	my ($self, $module_name, $referent_type, $referent_name) = @_;

	my $referent_module = $self->get_referent_module($module_name);

	my $cache_name = Pod::Plexus::Matter->calc_cache_name(
		$referent_type, $referent_name
	);

	my $referent = $referent_module->find_matter($cache_name);

	unless ($referent) {
		my $element = $self->element();
		chomp(my $content = $element->content());
		die [
			"Can't find matter referred to" .
			" in '=" . $element->command() . " $content'" .
			" at " . $self->module_pathname() .
			" line " . $element->start_line()
		];
	}

	return $referent;
}


no Moose;

1;
