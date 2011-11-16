package Pod::Plexus::Matter::include;

=abstract Include documentation from another section or boilerplate.

=cut

use Moose;
extends 'Pod::Plexus::Matter::Reference';

use Pod::Plexus::Matter::attribute;
use Pod::Plexus::Matter::method;


sub is_top_level { 0 }


sub BUILD {
	my $self = shift();

	my $element = $self->docs()->[ $self->docs_index() ];
	my $content = $element->content();
	chomp $content;

	my ($module, $type, $symbol);

	if (
		$content =~ m{
			^\s* (\S*) \s+ (attribute|boilerplate|method) \s+ (\S.*?) \s*$
		}x
	) {
		($module, $type, $symbol) = ($1, "Pod::Plexus::Matter::$2", $3);
	}
	elsif ($content =~ m/^\s* (attribute|boilerplate|method) \s+ (\S.*?) \s*$/x) {
		($module, $type, $symbol) = (
			$self->module_package(), "Pod::Plexus::Matter::$1", $2
		);
	}
	else {
		$self->push_error(
			"Wrong syntax: (=include $content) " .
			" at " . $self->module_pathname() .
			" line " . $element->start_line()
		);
		return;
	}

	my $referent_module = $self->module_distribution()->get_module($module);
	unless ($referent_module) {
		$self->push_error(
			"Unknown referent module: (=include $content) " .
			" at " . $self->module_pathname() .
			" line " . $element->start_line()
		);
		return;
	}

	my @errors = $referent_module->cache_structure();
	if (@errors) {
		$self->push_error(@errors);
		return;
	}

	my $referent = $referent_module->get_docs_matter($type, $symbol);
	unless ($referent) {
		$self->push_error(
			"Can't find referent in " . $referent_module->docs() .
			": (=include $content) " .
			" at " . $self->module_pathname() .
			" line " . $element->start_line()
		);
		return;
	}

	$self->name($symbol);
	$self->referent($referent);
	$self->doc_body($referent->clone_body());

	return;
}


no Moose;

1;
