package Pod::Plexus::Module::Subset;

use Moose;

=abstract Common features of Pod::Plexus::Module subsets (Code and Docs).

=cut


=attribute module

"[% s.name %]" holds the Pod::Plexus::Module object that owns this
[% m.package %] object.  It allows [% m.package %] to examine the
documentation for its code.

=cut

has module => (
	is       => 'ro',
	isa      => 'Pod::Plexus::Module',
	required => 1,
	weak_ref => 1,
);


=attribute distribution

"[% s.name %]" contains a reference to [% m.package %]'s distribution.

=cut

has distribution => (
	is       => 'ro',
	isa      => 'Pod::Plexus::Distribution',
	weak_ref => 1,
	lazy     => 1,
	default  => sub { shift()->module()->distribution() },
);


=inherits Pod::Plexus::Cli attribute verbose

=cut

has verbose => (
	is       => 'rw',
	isa      => 'Bool',
	required => 1,
);


no Moose;

1;
