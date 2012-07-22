package Pod::Plexus::Matter::example::attribute;

# TODO - Edit pass 0 done.


=abstract Render an attribute implementation as a code example.

=cut


=head1 SYNOPSIS

Include an example from an attribute in the current package:

	=example attribute attribute_name

Include an attribute from another package as an example here:

	=example AnotherPackage attribute attribute_name

=cut


=head1 DESCRIPTION

[% m.package %] objects manage, represent, and render code examples
from actual code.

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
