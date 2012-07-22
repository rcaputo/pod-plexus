package Pod::Plexus::Code;
# TODO - Edit pass 1 done.

use Moose;
use Carp qw(confess);


=abstract A base class to represent a code method or attribute in Pod::Plexus.

=cut


=head1 SYNOPSIS

=xref module Pod::Plexus::Code::Attribute

=xref module Pod::Plexus::Code::Method

=cut


=head1 DESCRIPTION

[% m.name %] is a base class for objects that represent code within a
distribution.  Code objects are used to validate documentation:

=over 4

=item * Is everything documented?

=item * Does all documentation refer to something in the code?

=back

Code objects are also used to include code examples in the
documentation.

=cut


=method new

=include Pod::Plexus boilerplate new

=cut

=attribute name

[% SWITCH m.package %]
[% CASE 'Pod::Plexus::Code::Method' %]
[% SET entity_type='method' %]
[% CASE 'Pod::Plexus::Code::Attribute' %]
[% SET entity_type='attribute' %]
[% CASE DEFAULT %]
[% SET entity_type='attribute or method' %]
[% END %]

"[% s.name %]" contains the name of the [% entity_type %] this object
represents.

=cut

has name => (
	is       => 'ro',
	isa      => 'Str',
	required => 1,
);


=attribute private

"[% s.name %]" indicates whether the code entity is private.  The
default implementation interprets a leading underscore as an
indication of privacy.  So method foo() is considered public, but
method _foo() is considered private.

=cut

has private => (
	is      => 'ro',
	isa     => 'Bool',
	lazy    => 1,
	default => sub { (shift()->name() =~ /^_/) || 0 },
);


=attribute meta_entity

[% s.name %] contains the L<Class::MOP> object representing this
entity in Moose.  It's set by Pod::Plexus::Module while caching the
class's code structure.  Pod::Plexus uses it to inspect the entity and
write default documentation for it.

=cut

has meta_entity => (
	is       => 'ro',
	isa      => 'Undef',
);


sub _UNUSED_is_documented {
	my ($self, $module, $errors) = @_;
	push @$errors, "Object $self ... class needs to override validate()";
}


sub _UNUSED_validate {
	my ($self, $module, $errors) = @_;
	push @$errors, "Object $self ... class needs to override validate()";
}


=attribute cache_name

"[% s.name %]" contains the code entity's unique cache name.  It's
calculated by calc_cache_name() and saved in the attribute for quicker
access later.

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

[% s.name %]() calculates a code entity's unique cache from two
parameters: the entity's type and its name in the class' symbol table.

[% s.name %] may be called as a class or object method.  If the
caller has the object but not all the necessary parameters, it may be
more convenient to access the "cache"name" attribute instead.

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
