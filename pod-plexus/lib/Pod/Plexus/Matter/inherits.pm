package Pod::Plexus::Matter::inherits;

=abstract Inherit a Pod::Plexus documentation section wholesale.

=cut

use Moose;
extends 'Pod::Plexus::Matter::include';


sub is_top_level { 1 }


sub BUILD {
	my $self = shift();
	my $referent = $self->referent();
	$self->doc_prefix($referent->clone_prefix());
	$self->handle_body();
};


sub handle_body {
	my $self = shift();
	$self->discard_my_section();
}


no Moose;

1;
