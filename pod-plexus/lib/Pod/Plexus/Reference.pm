package Pod::Plexus::Reference;

=abstract A generic expandable documentation reference.

=cut

=head1 SUBCLASSES

=index2 ^Pod::Plexus::Reference::

=cut

use Moose;
with 'Pod::Plexus::Role::Documentable';

=attribute key

[% ss.name %] contains a reference's unique identifying key.  It calls
calc_key() to calculate it, then caches it for faster use later.

=cut

has key => (
	is      => 'ro',
	isa     => 'Str',
	lazy    => 1,
	default => sub {
		my $self = shift();
		return $self->calc_key(ref($self), $self->module(), $self->symbol());
	},
);


=method calc_key

[% ss.name %] calculates a reference's unique key from three
parameters: the reference's class name, the reference's module name,
and an optional symbol within the module.  Omit the symbol to
reference the module as a whole.

[% ss.name %] may be called as a class or object method.  If the
caller has the object but not all the necessary parameters, it may be
more convenient to access the key() attribute instead.

=cut

sub calc_key {
	(undef, my ($type, $module, $symbol)) = @_;
	$symbol //= "";
	return join("\t", $type, $module, ($symbol // ""));
}


=attribute invoked_in

[% ss.name %] contains the package the reference was invoked in.

=cut

has invoked_in => (
	is       => 'ro',
	isa      => 'Str',
	required => 1,
);


=attribute invoke_path

[% ss.name %] contains the path of the file invoking this reference.

=cut

has invoke_path => (
	is       => 'ro',
	isa      => 'Str',
	required => 1,
);


=attribute invoke_line

[% ss.name %] contains the line number of this reference's invocation.

=cut

has invoke_line => (
	is       => 'ro',
	isa      => 'Int',
	required => 1,
);


=attribute module

[% ss.name %] contains the module being referenced.  This is required.

=cut

has module => (
	is       => 'ro',
	isa      => 'Str|RegexpRef',
	required => 1,
);


=attribute symbol

[% ss.name %] optinally references a particular symbol in the module
being referenced.  If omitted, the reference will apply to the target
module() as a whole.

=cut

has symbol => (
	is       => 'ro',
	isa      => 'Str',
	required => 1,
);


=method is_local

[% ss.name %] returns true if the reference is local within the module
invoking it.

=cut

sub is_local {
	my $self = shift();
	return $self->invoked_in() eq $self->module();
}

no Moose;

1;
