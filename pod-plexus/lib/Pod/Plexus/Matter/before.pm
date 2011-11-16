package Pod::Plexus::Matter::before;

=abstract Inherit documentation, and prepend new content before it.

=cut

use Moose;
extends 'Pod::Plexus::Matter::inherits';

use Pod::Plexus::Util::PodElemental qw(blank_line);


sub handle_body {
	my $self = shift();
	$self->unshift_body( $self->extract_my_section(), blank_line() );
}


no Moose;

1;
