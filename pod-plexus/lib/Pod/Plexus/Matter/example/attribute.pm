package Pod::Plexus::Matter::example::attribute;

use Moose;
extends 'Pod::Plexus::Matter::example';


sub BUILD {
	my $self = shift();

	my $attribute_name = $self->name();
	my $code = $self->referent()->get_attribute_code($attribute_name);

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
