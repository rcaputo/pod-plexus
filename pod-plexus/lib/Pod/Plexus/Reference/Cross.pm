package Pod::Plexus::Reference::Cross;

use Moose;
extends 'Pod::Plexus::Reference';

has '+symbol' => (
	isa      => 'Maybe[Str]',
	required => 0,
);

no Moose;

1;
