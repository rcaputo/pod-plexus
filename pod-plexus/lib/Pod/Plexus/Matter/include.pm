package Pod::Plexus::Matter::include;

# TODO - Edit pass 0 done.

=abstract Include documentation from another section or boilerplate.

=cut

use Moose;
extends 'Pod::Plexus::Matter::Reference';
with 'Pod::Plexus::Matter::Role::HasNoBody';

use Pod::Plexus::Matter::attribute;
use Pod::Plexus::Matter::method;


sub is_top_level { 0 }


sub BUILD {
	my $self = shift();

	my $element = $self->docs()->[ $self->docs_index() ];
	my $content = $element->content();

	my ($module_name, $referent_type, $referent_name);

	if (
		$content =~ m{
			^\s* (\S+) \s+ (attribute|boilerplate|method) \s+ (\S+) \s*$
		}x
	) {
		($module_name, $referent_type, $referent_name) = (
			$1, "Pod::Plexus::Matter::$2", $3
		);
	}
	elsif ($content =~ m/^\s* (attribute|boilerplate|method) \s+ (\S+) \s*$/x) {
		($module_name, $referent_type, $referent_name) = (
			$self->module_package(), "Pod::Plexus::Matter::$1", $2
		);
	}
	else {
		die [
			"Wrong syntax" .
			" in '=" . $element->command() . " $content'" .
			" at " . $self->module_pathname() .
			" line " . $element->start_line()
		];
	}

	my $referent = $self->get_referent_matter(
		$module_name, $referent_type, $referent_name
	);

	$self->name($referent_name);
	$self->referent($referent);
	$self->doc_body($referent->clone_body());

	return;
}


no Moose;

1;
