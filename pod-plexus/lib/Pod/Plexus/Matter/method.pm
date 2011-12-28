package Pod::Plexus::Matter::method;

# TODO - Edit pass 0 done.

=abstract A reference to documentation for a class method.

=cut


=head1 SYNOPSIS

	=method new_from_element

	Prose documenting the method.

	=cut

=cut


=head1 DESCRIPTION

"=method" is a Pod::Weaver directive.  Pod::Plexus::Matter::method
remembers method documentation and allows Pod::Plexus to manipulate
them as well.

Method documentation can be imported into other places using
"=inherits", "=before", "=after" and "=include".

=over 4

=xref method Pod::Plexus::Matter::after

=xref method Pod::Plexus::Matter::before

=xref method Pod::Plexus::Matter::include

=xref method Pod::Plexus::Matter::inherits

=back

Method documentation can be referenced using "=xref".

=over 4

=xref method Pod::Plexus::Matter::xref

=back

=cut


use Moose;
extends 'Pod::Plexus::Matter::Code';

use Pod::Plexus::Util::PodElemental qw(generic_command blank_line);


sub is_top_level { 1 }


has '+doc_prefix' => (
	default => sub {
		my $self = shift();
		return [
			generic_command("method", $self->name() . "\n"),
			blank_line(),
		];
	},
);


no Moose;

1;
