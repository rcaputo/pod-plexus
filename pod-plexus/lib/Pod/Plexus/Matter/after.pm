package Pod::Plexus::Matter::after;

=abstract Inherit documentation, and append new content to the section.

=cut

use Moose;
extends 'Pod::Plexus::Matter::inherits';

use Pod::Plexus::Util::PodElemental qw(blank_line);

sub handle_body {
	my $self = shift();
	$self->push_body( blank_line(), $self->extract_my_section() );
};


no Moose;

1;
