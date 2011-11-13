package Pod::Plexus::Docs::after;

=abstract Inherit documentation, and add content after it.

=cut

use Moose;
extends 'Pod::Plexus::Docs::inherits';

use Pod::Plexus::Util::PodElemental qw(blank_line);

sub handle_body {
	my $self = shift();
	$self->push_body( blank_line(), $self->extract_my_section() );
};


no Moose;

1;
