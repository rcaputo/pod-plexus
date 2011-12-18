package Pod::Plexus::Matter::Reference;
# TODO - Edit pass 1 done.

use Moose;
extends 'Pod::Plexus::Matter';
with 'Pod::Plexus::Matter::Role::HasNoBody';


=abstract An abstract section that references something else.

=cut


=attribute referent

"[% s.name %]" contains a reference to the Pod::Plexus::Matter object
referred to by this [% m.package %] object.  Subclasses use it to
inspect and possibly clone the documentation being referenced.

The type of object stored in "[% s.name %]" depends upon what is being
referenced.

=cut

has referent => (
	is       => 'rw',
	isa      => 'Pod::Plexus::Matter',
	weak_ref => 1,
);


=method get_referent_module

[% s.name %](PACKAGE_NAME) returns a Pod::Plexus::Module object that
represents the supplied PACKAGE_NAME.  Subclasses use it to inspect
the module for information such as its abstract, or to acquire code or
documentation from it

=cut

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


=method get_referent_matter

[% s.name %](PACKAGE_NAME, REFERENT_TYPE, REFERENT_NAME) returns a
Pod::Plexus::matter object representing the documentation specified by
a PACKAGE_NAME, a REFERENT_TYPE and a REFERENT_NAME.

Pod::Plexus::Matter::include uses this to find documentation that it
will include.

=cut

sub get_referent_matter {
	my ($self, $module_name, $referent_type, $referent_name) = @_;

	my $referent_module = $self->get_referent_module($module_name);
	$referent_module->cache_structure();

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
