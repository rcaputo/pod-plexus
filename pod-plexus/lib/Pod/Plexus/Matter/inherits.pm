package Pod::Plexus::Matter::inherits;

# TODO - Edit pass 0 done.

=abstract Inherit a method or attribute section from somewhere else.

=cut


=head1 SYNOPSIS

	=inherits Package [attribute|method] symbol_name

	=cut

=cut


=boilerplate expansions

Template symbols will be evaluated in the inheritor's namespace, so
things like "[Z<>% m.package %]" will render correctly.

These directives are POD sections for the sake of POD correctness and
editor highlighting and folding.  They may not contain content,
however, since the content will be inherited from elsewhere.

=cut


=head1 DESCRIPTION

[% m.package %] implements the "=inherits" Pod::Plexus directive.  It
allows POD in one module to incorporate attribute or method
documentation from another module.

=include boilerplate expansions

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
