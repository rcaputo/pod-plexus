package Pod::Plexus::Matter::example::function;

# TODO - Edit pass 0 done.

=abstract Document a class function in an inheritable way.

=cut


=head1 SYNOPSIS

	=head1 SOME EXAMPLES

	An example coming from the current package:

	=example function in_this_package

	An example coming from some other package:

	=example Some::Other::Package function in_another_package

	=cut

=cut


=head1 DESCRIPTION

[% m.package %] determines how the "function" variant of "=example"
commands are interpreted and their resulting documentation is
rendered.

=cut


use Moose;
extends 'Pod::Plexus::Matter::example';


sub BUILD {
	my $self = shift();

	my $referent = $self->get_referent_module($self->referent_name());
	$self->referent($referent);

	my $function_name = $self->name();
	my $code = $referent->get_method_source($function_name);

	my $link;
	if ($self->_is_local()) {
		$link = "This is function L<$function_name()|/$function_name>.\n";
	}
	else {
		my $module_name = $self->referent_name();
		$link = (
			"This is L<$module_name|$module_name> " .
			"function L<$function_name()|$module_name/$function_name>.\n"
		);
	}

	$self->_set_example($link, $code);
}


no Moose;

1;
