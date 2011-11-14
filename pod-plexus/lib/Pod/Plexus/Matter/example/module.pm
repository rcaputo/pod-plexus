package Pod::Plexus::Matter::example::module;

=abstract Render the code for a whole module as an example.

=cut

use Moose;
extends 'Pod::Plexus::Matter::example';


sub BUILD {
	my $self = shift();

	my $module_name = $self->referent_name();
	my $code = $self->referent()->get_module_code();
	my $link = "This is L<$module_name|$module_name>.\n";

	$self->_set_example($link, $code);
}


no Moose;

1;
