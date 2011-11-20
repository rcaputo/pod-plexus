package Pod::Plexus::Matter::example::attribute;

# TODO - Edit pass 0 done.

=abstract Render an attribute implementation as a code example.

=cut

use Moose;
extends 'Pod::Plexus::Matter::example';


sub BUILD {
	my $self = shift();

	my $referent = $self->get_referent_module($self->referent_name());
	$self->referent($referent);

	my $attribute_name = $self->name();
	my $code = $referent->get_attribute_source($attribute_name);

	my $link;
	if ($self->_is_local()) {
		$link = "This is attribute L<$attribute_name|/$attribute_name>.\n";
	}
	else {
		my $module_name = $self->referent_name();
		$link = (
			"This is L<$module_name|$module_name> " .
			"attribute L<$attribute_name()|$module_name/$attribute_name>.\n"
		);
	}

	$self->_set_example($link, $code);
}


no Moose;

1;
