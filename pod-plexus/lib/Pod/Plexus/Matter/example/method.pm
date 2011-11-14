package Pod::Plexus::Matter::example::method;

use Moose;
extends 'Pod::Plexus::Matter::example';


sub BUILD {
	my $self = shift();

	my $method_name = $self->name();
	my $code = $self->referent()->get_sub_code($method_name);

	my $link;
	if ($self->_is_local()) {
		$link = "This is method L<$method_name()|/$method_name>.\n";
	}
	else {
		my $module_name = $self->referent_name();
		$link = (
			"This is L<$module_name|$module_name> " .
			"method L<$method_name()|$module_name/$method_name>.\n"
		);
	}

	$self->_set_example($link, $code);
}


no Moose;

1;
