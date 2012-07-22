package Pod::Plexus::Matter::example::module;

# TODO - Edit pass 0 done.


=abstract Render the code for a whole module as an example.

=cut


=head1 SYNOPSIS

Use an entire module as an example:

	=example SomePackageName

=cut


=head1 DESCRIPTION

[% m.package %] objects mange and render examples using modules'
entire implementations.  It's most useful for small modules or
programs.

=cut


use Moose;
extends 'Pod::Plexus::Matter::example';


sub BUILD {
	my $self = shift();

	my $module_name = $self->referent_name();
	my $referent = $self->get_referent_module($module_name);
	$self->referent($referent);

	my $link = "This is L<$module_name|$module_name>.\n";

	my $code = $referent->get_module_code();
	$self->_set_example($link, $code);
}


no Moose;

1;
