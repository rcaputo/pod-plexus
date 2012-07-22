package Pod::Plexus::Matter::attribute;

# TODO - Edit pass 0 done.


=abstract Document a class attribute in an inheritable way.

=cut


=head1 SYNOPSIS

	=attribute matter

	"[Z<>% s.name %]" contains a hash table of Pod::Plexus::Matter
	objects that have been added to the module using add_matter().

	=cut

=cut


=head1 DESCRIPTION

"=attribute" is a Pod::Weaver directive that documents an object
attribute.  Pod::Plexus::Matter::attribute remembers and represents
attribute documentation.  Pod::Plexus manages attribute documentation
using these objects.

=cut


use Moose;
extends 'Pod::Plexus::Matter::Code';

use Pod::Plexus::Util::PodElemental qw(generic_command blank_line);


sub is_top_level { 1 }


has '+doc_prefix' => (
	default => sub {
		my $self = shift();
		return [
			generic_command("attribute", $self->name() . "\n"),
			blank_line(),
		];
	},
);


no Moose;

1;
