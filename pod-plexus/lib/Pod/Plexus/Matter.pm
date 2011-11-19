package Pod::Plexus::Matter;

=abstract A generic segment of documentation matter.

=cut

=head1 SUBCLASSES

=toc ^Pod::Plexus::Matter::

=cut

use Moose;
use Carp qw(croak);

use Pod::Plexus::Util::PodElemental qw(cleanup_element_arrayref);
use Storable qw(dclone);


=method is_inheritable

The [% s.name %] flag tells Pod::Plexus::Module::Docs whether a piece
of documentation matter may be inherited through "=inherits",
"=before" and "=after".  It is false by default.

=cut

sub is_inheritable { 0 }


=attribute module

"[% s.name %]" holds the Pod::Plexus::Module that contains this
documentation matter.

=cut

has module => (
	is       => 'ro',
	isa      => 'Pod::Plexus::Module',
	weak_ref => 1,
	required => 1,
	handles  => {
		module_package      => 'package',
		module_abstract     => 'abstract',
		module_distribution => 'distribution',
		module_pathname     => 'pathname',
	},
);


=attribute name

Most documentation matter has a name.  The "[% s.name %]" attribute
contains that name for referencing and documentation expansion
purposes.

=cut

has name => (
	is      => 'rw',
	isa     => 'Str',
	default => "",
);


=inherits Pod::Plexus::Cli attribute verbose

=cut

has verbose => (
	is       => 'ro',
	isa      => 'Bool',
	required => 1,
);


=attribute docs

The current Pod::Plexus::Matter object exists within its module's
documentation.  The "[% s.name %]" attribute holds the documentation
for the entire module.  Subclasses use it and "[% s.name %]_index" to
parse their documentation and replace themselves with
Pod::Plexus::Matter objects.

=cut

has docs => (
	is       => 'ro',
	isa      => 'ArrayRef[Pod::Elemental::Paragraph|Pod::Plexus::Matter]',
	required => 1,
	weak_ref => 1,
);


=attribute docs_index

"[% s.name %]" contains this Pod::Plexus::Matter object's index inside
the "docs" attribute.  It's used to splice a new [% m.name %] object
into the documentation where the corresponding Pod::Plexus command
appeared.

=cut

has docs_index => (
	is       => 'ro',
	isa      => 'Int',
	required => 1,
);


=boilerplate doc_attribute

Each Pod::Plexus::Matter object represents up to three pieces of
documentation: (1) An optional documentation prefix, which is often a
"=head" or "=item" command of some sort.  (2) The documentation body,
which is the section's main prose.  (3) An optional documentation
suffix, which is often just "=cut".

=cut


=attribute doc_prefix

=include boilerplate doc_attribute

"[% s.name %]" contains the POD section prefix.  Subclasses often
override it to format their data into POD.

=cut

has doc_prefix => (
	is      => 'rw',
	isa     => 'ArrayRef[Pod::Elemental::Paragraph]',
	traits  => [ 'Array' ],
	lazy    => 1,
	default => sub { [ ] },
	handles => {
		has_prefix  => 'count',
		push_prefix => 'push',
	},
);


=attribute doc_body

=include boilerplate doc_attributes

"[% s.name %]" contains the main body of documentation for a piece of
Pod::Plexus::Matter.

Pod::Plexus::Matter includes a couple helper methods to deal with
section bodies.  See extract_my_section() and discard_my_section() for
standard ways to deal with text in a Pod::Plexus documentation
section.

=cut

has doc_body => (
	is      => 'rw',
	isa     => 'ArrayRef[Pod::Elemental::Paragraph|Pod::Plexus::Matter]',
	traits  => [ 'Array' ],
	#lazy    => 1,
	default => sub { [ ] },
	handles => {
		has_body     => 'count',
		push_body    => 'push',
		unshift_body => 'unshift',
	},
);


=attribute doc_suffix

=include boilerplate doc_attributes

"[% s.name %]" ends the documentation represented by a
Pod::Plexus::Matter object.  It's mostly either "=cut" for matter that
represents entire POD sections.  It's often empty for matter
representing inclusions that aren't entire sections on their own.

=cut

has doc_suffix => (
	is      => 'rw',
	isa     => 'ArrayRef[Pod::Elemental::Paragraph|Pod::Plexus::Matter]',
	traits  => [ 'Array' ],
	lazy    => 1,
	default => sub { [ ] },
	handles => {
		has_suffix  => 'count',
		push_suffix => 'push',
	},
);


=boilerplate cloning_docs

Pod::Plexus is "documentation by reference".  Dereferencing is
implemented by cloning bits of the objects representing documentation.

=cut


=method clone_prefix

[% s.name %]() is a helper method to clone a Pod::Plexus::Matter
object's "doc_prefix" attribute, so that inheritors don't need to
worry about modifications from a distance.

=include boilerplate cloning_docs

=cut

sub clone_prefix {
	my $self = shift;
	return dclone $self->doc_prefix();
}


=method clone_body

[% s.name %]() is a helper method to clone a Pod::Plexus::Matter
object's "doc_body" attribute, so that inheritors don't need to worry
about modifications from a distance.

=include boilerplate cloning_docs

=cut

sub clone_body {
	my $self = shift;
	return dclone $self->doc_body();
}


=method clone_suffix

[% s.name %]() is a helper method to clone a Pod::Plexus::Matter
object's "doc_suffix" attribute, so that inheritors don't need to
worry about modifications from a distance.

=include boilerplate cloning_docs

=cut

sub clone_suffix {
	my $self = shift;
	return dclone $self->doc_suffix();
}


sub as_pod_string {
	my ($self, $section) = @_;
	$section //= $self;

	my $template_obj = $self->module_distribution()->template();

	my $template_input = join(
		"",
		map { $_->as_pod_string($section) }
		$self->as_pod_elementals()
	);

	my %template_vars = (
		d => $self->module_distribution(),
		m => $self->module(),
		s => $section,
		r => $self,
	);

	my $template_output = "";
	$template_obj->process(
		\$template_input, \%template_vars, \$template_output
	) or die $template_obj->error();

	return $template_output;
}


sub as_pod_elementals {
	my $self = shift();

	my @return = (
		@{ $self->doc_prefix() },
		@{ $self->doc_body()   },
		@{ $self->doc_suffix() },
	);

	cleanup_element_arrayref(\@return);

	return @return;
}


=attribute key

[% s.name %] contains a reference's unique identifying key.  It calls
calc_key() to calculate it, then caches it for future speed.

=cut

has key => (
	is      => 'ro',
	isa     => 'Str',
	lazy    => 1,
	default => sub {
		my $self = shift();
		return $self->calc_key(ref($self), $self->name());
	},
);


=method calc_key

[% s.name %] calculates a reference's unique key from three
parameters: the reference's class name, the reference's module name,
and an optional symbol within the module.  Omit the symbol to
reference the module as a whole.

[% s.name %] may be called as a class or object method.  If the
caller has the object but not all the necessary parameters, it may be
more convenient to access the key() attribute instead.

=cut

sub calc_key {
	(undef, my ($type, $symbol)) = @_;
	$type =~ s/^Pod::Plexus::Matter:://;
	return join("\t", $type, ($symbol // ""));
}


has errors => (
	is      => 'ro',
	isa     => 'ArrayRef[Str]',
	traits  => [ 'Array' ],
	default => sub { [ ] },
	handles => {
		failed     => 'count',
		push_error => 'push',
	},
);


sub extract_my_section {
	my $self = shift();

	my $docs = $self->docs();
	my $i    = $self->docs_index() + 1;

	my @return;
	ELEMENT: while ($i < @$docs) {
		my $element = $docs->[$i];

		if ($element->isa('Pod::Elemental::Element::Generic::Command')) {
			my $command = $element->command();

			# Save the start of the following thing.
			last ELEMENT if $command eq 'head1';

			splice(@$docs, $i, 1);

			# But we can discard cuts.
			last ELEMENT if $command eq 'cut';

			push @return, $element;
			next ELEMENT;
		}

		last ELEMENT if (
			$element->isa('Pod::Plexus::Matter') and
			$element->is_top_level()
		);

		push @return, splice(@$docs, $i, 1);
		next ELEMENT;
	}

	cleanup_element_arrayref(\@return);

	return @return;
}


sub discard_my_section {
	my $self = shift();
	my @section = $self->extract_my_section();
	return unless @section;

	my $element = $self->docs()->[ $self->docs_index() ];
	my $command = $element->command();

	$self->push_error(
		"=$command section must be empty" .
		" at " . $self->module_pathname() .
		" line " . $element->start_line()
	);
}


sub new_from_element {
	my $class = shift();
	return $class->new(@_);
}


no Moose;

1;
