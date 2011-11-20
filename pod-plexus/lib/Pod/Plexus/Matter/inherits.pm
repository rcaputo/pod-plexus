package Pod::Plexus::Matter::inherits;

# TODO - Edit pass 0 done.

=abstract Inherit a method or attribute section from somewhere else.

=cut

use Moose;
extends 'Pod::Plexus::Matter::include';


sub is_top_level { 1 }


sub BUILD {
	my $self = shift();

	my $referent = $self->referent();
	return unless $referent;

	$self->doc_prefix($referent->clone_prefix());
	$self->doc_suffix($referent->clone_suffix());
};


no Moose;

1;
