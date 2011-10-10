package Pod::Plexus::Code;

use Moose;

use Carp qw(confess);

=attribute name

[% ss.name %] contains this Pod::Plexus entity's name.

=cut

has name => (
	is       => 'ro',
	isa      => 'Str',
	required => 1,
);


=attribute private

[% ss.name %] is a read-only accessor that tells whether the entity is
public or private.  By default, entities with names beginning with one
or more underscores are considered private.  All others are considered
public.

=cut

has private => (
	is      => 'ro',
	isa     => 'Bool',
	lazy    => 1,
	default => sub { (shift()->name() =~ /^_/) || 0 },
);


=attribute meta_entity

[% ss.name %] contains the Class::MOP object representing this entity
in Moose.  It's added by Pod::Plexus::Document during its indexing
phase.

=cut

has meta_entity => (
	is       => 'ro',
	isa      => 'Undef',
	#required => 1,
);


sub is_documented {
	my ($self, $document, $errors) = @_;
	push @$errors, "Object $self ... class needs to override validate()";
}

sub validate {
	my ($self, $document, $errors) = @_;
	push @$errors, "Object $self ... class needs to override validate()";
}


no Moose;

1;

=abstract A code attribute or method entity.

=cut

=method new

Constructs one [% mod.package %] object.  See L</PUBLIC ATTRIBUTES>
for constructor options.

=cut
