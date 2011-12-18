package Pod::Plexus::Matter;
# TODO - Edit pass 1 done.

use Moose;
use Carp qw(croak);

use Pod::Plexus::Util::PodElemental qw(cleanup_element_arrayref blank_line);
use Storable qw(dclone);

=abstract A generic segment of documentation matter.

=cut


=head1 SUBCLASSES

=toc ^Pod::Plexus::Matter::

=cut


=boilerplate please_report_questions

The rest of this documentation covers internal implementation details
that casual users shouldn't need to know.  Please report any usage
questions as bugs.  If readers find themselves looking into the code
to understand usage, then the documentation is broken.

=cut


=method is_top_level

[% s.name %]() returns true if [% m.package %] implements a top-level
documentation container.  All POD and Pod::Plexus documentation after
this Pod::Plexus command will be grouped into a single section.  The
section is terminated by "=cut" or the start of another top-level
command.

[% s.name %]() applies to all objects of the class, so it is
implemented as a class method.

[% IF m.package != 'Pod::Plexus::Matter' %]
[% IF m.package.call('is_top_level') %]
[% m.package %] objects represent top-level documentation matter.
[% ELSE %]
[% m.package %] objects are not top-level documentation matter.
[% END %]
[% END %]

=cut

sub is_top_level { 0 }


=attribute module

"[% s.name %]" holds the Pod::Plexus::Module that contains this
documentation matter.  It allows documentation matter to inspect
aspects of the module it's documenting.

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
contains the name of the thing being documented, such as an attribute
or method name.

=cut

has name => (
	is      => 'rw',
	isa     => 'Str',
	default => "",
);


=attribute element

The "[% s.name %]" attribute contains the L<Pod::Elemental::Paragraph>
object that describes the [% m.package %] being created.  Pod::Plexus
parsers may use it to access the command() and content() that caused
their creation, as well as the command's source line number for error
reporting.

=cut

has element => (
	is        => 'ro',
	isa       => 'Pod::Elemental::Paragraph',
	required  => 1,
);


=inherits Pod::Plexus::Cli attribute blame

=cut

has blame => (
	is       => 'ro',
	isa      => 'Bool',
	required => 1,
);


=inherits Pod::Plexus::Cli attribute verbose

=cut

has verbose => (
	is       => 'ro',
	isa      => 'Bool',
	required => 1,
);


=attribute docs

"[% s.name %]" includes the list of Pod::Elemental paragraphs that
make up the entire documentation of [% m.package %].  It's used in
conjunction with "[% s.name %]_index" to locate and handle a
Pod::Plexus command's text content.

=cut

has docs => (
	is       => 'ro',
	isa      => 'ArrayRef[Pod::Elemental::Paragraph|Pod::Plexus::Matter]',
	required => 1,
	weak_ref => 1,
);


=attribute docs_index

This [% m.package %] object was created from a
Pod::Elemental::Paragraph object held in "docs".  "[% s.name %]"
contains the index within "docs" where that Pod::Elemental::Paragraph
is stored.

"docs" and "[% s.name %]" together help [% m.package %] learn more
about itself, including the raw text used to configure itself and the
source line to report in case of error.

=cut

has docs_index => (
	is       => 'ro',
	isa      => 'Int',
	required => 1,
);


=boilerplate doc_attributes

Each Pod::Plexus::Matter object represents up to three pieces of
documentation:

=over 4

=item 1.

An optional documentation prefix, which is often a Pod::Elemental
"=head" or "=item" command of some sort followed by a blank line.

=item 2.

The documentation body, which is the section's main prose.

=item 3.

An optional documentation suffix, which is often just "=cut".

=back

=cut


=attribute doc_prefix

"[% s.name %]" contains the documentation that begins a Pod::Plexus
section.  Subclasses often customize the POD they generate by
overriding the default value or setting it from BUILD.

=include boilerplate doc_attributes

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

"[% s.name %]" contains the main body of documentation for a piece of
Pod::Plexus::Matter.

Pod::Plexus provides some roles that help set "[% s.name %]" in
standard ways.

=toc ^Pod::Plexus::Matter::Role::

=include boilerplate doc_attributes

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

"[% s.name %]" ends the documentation represented by a
Pod::Plexus::Matter object.  It's often either "=cut" for matter that
represents entire POD sections, or empty for matter that is included
in other sections.

Subclasses usually customize it by overriding its default value or
setting it from BUILD.

=include boilerplate doc_attributes

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

Pod::Plexus is "documentation by reference".  Cloning is done by copy,
not by reference, so that each Pod::Plexus::Matter object can edit its
content without affecting those from which the content was inherited.

=cut


=method clone_prefix

[% s.name %]() is a helper method to clone a Pod::Plexus::Matter
object's "doc_prefix" attribute.

It returns an array reference suitable for setting into another
Pod::Plexus::Matter object's "doc_prefix" attribute.

=include boilerplate cloning_docs

=cut

sub clone_prefix {
	my $self = shift;
	return dclone $self->doc_prefix();
}


=method clone_body

[% s.name %]() is a helper method to clone a Pod::Plexus::Matter
object's "doc_body" attribute.

It returns an array reference suitable for setting into another
Pod::Plexus::Matter object's "doc_body" attribute.

=include boilerplate cloning_docs

=cut

sub clone_body {
	my $self = shift;

	local $SIG{__DIE__} = sub { confess "@_" };

	my @new_body;
	foreach my $sub_matter (@{$self->doc_body()}) {
		if ($sub_matter->isa('Pod::Plexus::Matter')) {
			my $new_matter = $sub_matter->meta()->clone_object($sub_matter);
			$new_matter->doc_body( $new_matter->clone_body() );
			push @new_body, $new_matter;
			next;
		}

		push @new_body, dclone($sub_matter);
		next;
	}

	return \@new_body;
}


=method clone_suffix

[% s.name %]() is a helper method to clone a Pod::Plexus::Matter
object's "doc_suffix" attribute.

It returns an array reference suitable for setting into another
Pod::Plexus::Matter object's "doc_suffix" attribute.

=include boilerplate cloning_docs

=cut

sub clone_suffix {
	my $self = shift;
	return dclone $self->doc_suffix();
}


=method as_pod_string

[% s.name %]() returns a string of multi-line POD represented by a
Pod::Plexus::Matter object and any of its contents.

Documentation references are dereferenced here.  Template variables
are expanded here.

=cut

sub as_pod_string {
	my ($self, $section) = @_;

	my $template_obj = $self->module_distribution()->template();
	my $blame_prefix = $self->blame() ? "$self " : "";

	my $template_input = join(
		"",
		map { $_ = $_->as_pod_string($section); s/^/$blame_prefix/mg; $_ }
		$self->as_pod_elementals()
	);

	my %template_vars = (
		d => $section->module_distribution(),
		m => $section->module(),
		s => $section,
		r => $self,
		c => $section->module()->package(),
	);

	my $template_output = "";
	$template_obj->process(
		\$template_input, \%template_vars, \$template_output
	) or die $template_obj->error();

	return $template_output;
}


=method as_pod_elementals

[% s.name %]() returns a list of Pod::Elemental paragraphs represented
by a Pod::Plexus::Matter object and any of its contents.

Documentation references are dereferenced here, but template variables
are not expanded yet.  They won't be expanded until as_pod_string() is
called on each element.

=cut

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


=attribute cache_name

"[% s.name %]" contains a reference's uniquely identifying cache name.
Its default value is created by calc_[% s.name %]().

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

[% s.name %]() calculates a Pod::Plexus::Matter object's uniquely
identifying cache name from two parameters: the type of matter being
documented, and the matter's name.  This isn't unique, however, until
it's combined with a module's namespace.

[% s.name %] may be called as a class or object method.  If the caller
has the object but not all the necessary parameters, it may be more
convenient to access the "cache_name" attribute instead.

=cut

sub calc_cache_name {
	(undef, my ($type, $symbol)) = @_;

	$type =~ s/^Pod::Plexus::Matter:://;
	$type =~ s/::/__/g;

	$symbol //= "";

	return "__pod_plexus_matter__$type\__$symbol\__";
}


=method extract_my_body

[% s.name %]() extracts the body text of a Pod::Plexus::Matter
section.  It uses "docs" and "docs_index" to find the text body within
the module's Pod::Elemental document.  The contents of that text body
are spliced out of the document and returned.  It's up to different
Pod::Plexus::Matter subclasses to do something appropriate with the
content.

Pod::Plexus provides some roles that handle text content in standard
ways.  Most of these use [% s.name %]() to do the bulk of their work.

=toc ^Pod::Plexus::Matter::Role::

=cut

sub extract_my_body {
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


=boilerplate new_from_element

[% s.name %]() is a hook to allow command handlers to create
subclasses based on the Pod::Plexus command syntax.  For example,
[% m.package %]::skip->[% s.name %] creates different objects
depending whether an attribute or a method is being skipped.

[% m.package %] uses the default implementation, which simply creates
a new [% m.package %] object.

=cut

sub new_from_element {
	my $class = shift();
	return $class->new(@_);
}


=skip method BUILD

=cut

sub BUILD {
	my $self = shift();
	$self->handle_body();
}


no Moose;

1;
