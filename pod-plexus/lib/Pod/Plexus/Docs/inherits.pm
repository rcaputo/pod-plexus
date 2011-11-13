package Pod::Plexus::Docs::inherits;

=abstract Inherit a Pod::Plexus documentation section wholesale.

=cut

use Moose;
extends 'Pod::Plexus::Docs::include';

sub BUILD {
	my $self = shift();
	my $referent = $self->referent();
	$self->doc_prefix($referent->clone_prefix());
	$self->handle_body();
};


sub handle_body {
	my $self = shift();
	my @section = $self->discard_my_section();
}


no Moose;

1;
