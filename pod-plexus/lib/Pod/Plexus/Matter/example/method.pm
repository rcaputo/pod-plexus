package Pod::Plexus::Matter::example::method;

# TODO - Edit pass 0 done.

=abstract Document a class method in an inheritable way.

=cut


=head1 SYNOPSIS

	=head1 SOME EXAMPLES

	An example coming from the current package:

	=example method in_this_package

	An example coming from some other package:

	=example Some::Other::Package method in_another_package

	=cut

=cut


=head1 DESCRIPTION

[% m.package %] determines how the "method" variant of "=example"
commands are interpreted and their resulting documentation is
rendered.

=cut


use Moose;
extends 'Pod::Plexus::Matter::example';


sub BUILD {
	my $self = shift();

	my $referent = $self->get_referent_module($self->referent_name());
	$self->referent($referent);

	my $method_name = $self->name();
	my $code = $referent->get_method_source($method_name);

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
