package Pod::Plexus::Code;

use Moose;

use Carp qw(confess);


=attribute name

[% s.name %] contains this Pod::Plexus entity's name.

=cut

has name => (
	is       => 'ro',
	isa      => 'Str',
	required => 1,
);


=attribute private

[% s.name %] is a read-only accessor that tells whether the entity is
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

[% s.name %] contains the Class::MOP object representing this entity
in Moose.  It's added by Pod::Plexus::Module during its indexing
phase.

=cut

has meta_entity => (
	is       => 'ro',
	isa      => 'Undef',
	#required => 1,
);


sub is_documented {
	my ($self, $module, $errors) = @_;
	push @$errors, "Object $self ... class needs to override validate()";
}


sub validate {
	my ($self, $module, $errors) = @_;
	push @$errors, "Object $self ... class needs to override validate()";
}


=attribute cache_name

[% s.name %] contains a reference's unique identifying key.  It calls
calc_cache_name() to calculate it, then caches it for future speed.

=cut

has cache_name => (
	is      => 'ro',
	isa     => 'Str',
	lazy    => 1,
	default => sub {
		my $self = shift();
		return $self->calc_cache_name(ref($self), $self->name());
	},
);


=method calc_cache_name

[% s.name %] calculates a reference's unique key from three
parameters: the reference's class name, the reference's module name,
and an optional symbol within the module.  Omit the symbol to
reference the module as a whole.

[% s.name %] may be called as a class or object method.  If the
caller has the object but not all the necessary parameters, it may be
more convenient to access the key() attribute instead.

=cut

sub calc_cache_name {
	(undef, my ($type, $symbol)) = @_;

	$type =~ s/^Pod::Plexus::Code:://;
	$type = lc($type);

	$symbol //= "";
	$symbol =~ s/^\+//;

	return "__pod_plexus_code__$type\__$symbol\__";
}


no Moose;

1;

=abstract A code attribute or method entity.

=cut

=method new

Constructs one [% m.package %] object.  See L</PUBLIC ATTRIBUTES>
for constructor options.

=cut
