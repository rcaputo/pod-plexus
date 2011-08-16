package Pod::Plexus::Reference;

=abstract A generic expandable documentation reference.

=cut

=head1 SUBCLASSES

=index 2 ^Pod::Plexus::Reference::

=cut

use Moose;
with 'Pod::Plexus::Role::Documentable';

use Carp qw(croak);


# Priorities.
#
# 9000 - Directives that control Pod::Plexus behavior.
# 5000 - Things which may appear within other POD containers.
# 1000 - Top-level POD containers.

=attribute discards_command

[% ss.name %] contains a boolean value that instructs Pod::Plexus::Document
whether to discard the POD commands for
this type of Pod::Plexus reference.

=cut

has discards_command => (
	is      => 'ro',
	isa     => 'Bool',
	default => 0,
);


=attribute discards_text

[% ss.name %] contains a boolean value that instructs Pod::Plexus::Document
whether to discard the text following
this type of Pod::Plexus reference.

[% ss.name %] is implied by includes_text().  If includes_text() is
true, then [% ss.name %] will count as true no matter what its actual
value.

=cut

has discards_text => (
	is      => 'ro',
	isa     => 'Bool',
	default => 0,
);


=attribute includes_text

[% ss.name %] contains a boolean value that instructs Pod::Plexus::Document
whether to include the text following POD commands in the objects for
this type of Pod::Plexus reference.

[% ss.name %] implies discards_text().  If [% ss.name %] is true, then
the documentation for this type of Pod::Plexus reference will include
the text following each command.

=cut

has includes_text => (
	is      => 'ro',
	isa     => 'Bool',
	default => 0,
);


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


=method new_from_elemental_command

[% ss.name %] does what the label says.  It parses a Pod::Elemental
command node, and it creates a new [% mod.name %] object from the
values found in that node.

=cut

sub new_from_elemental_command {
	my $class = shift();
	croak "$class->new_from_elemental_command() is a virtual method";
}


=method dereference

[% ss.name %] copies the documentation referenced by a [% mod.name %]
object into its documentation() attribute.

=cut

sub dereference {
	my $self = shift();
	croak "$self->dereference() is a virtual method";
}


=method expand

[% ss.name %] expands a Pod::Elemental command node into the
dereferenced documentation stored in the [% mod.name %] object's
documentation() attribute.

=cut

sub expand {
	my $self = shift();
	croak "$self->expand() is a virtual method";
}


no Moose;

1;
