package Pod::Plexus::Entity;

use Moose;

use Carp qw(confess);

has name => (
	is       => 'ro',
	isa      => 'Str',
	required => 1,
);

has private => (
	is => 'ro',
	isa => 'Bool',
	lazy => 1,
	default => sub { (shift()->name() =~ /^_/) || 0 },
);

no Moose;

1;
