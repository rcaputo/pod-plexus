package Pod::Plexus::Docs::before;

=abstract Inherit documentation, and add content before it.

=cut

use Moose;
extends 'Pod::Plexus::Docs::inherits';

use Pod::Plexus::Util::PodElemental qw(blank_line);


sub handle_body {
	my $self = shift();
	$self->unshift_body( $self->extract_my_section(), blank_line() );
}


no Moose;

1;
