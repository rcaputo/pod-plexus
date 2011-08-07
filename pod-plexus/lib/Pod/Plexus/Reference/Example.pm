package Pod::Plexus::Reference::Example;

use Moose;
extends 'Pod::Plexus::Reference';

has '+symbol' => (
	isa      => 'Maybe[Str]',
	required => 0,
);

no Moose;

1;
