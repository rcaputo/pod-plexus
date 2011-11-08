package Pod::Plexus::Docs;

=abstract A generic expandable documentation reference.

=head1 SUBCLASSES

=index 2 ^Pod::Plexus::Docs::

=cut

use Moose;
use Carp qw(croak);

use Pod::Plexus::Util::PodElemental qw(cleanup_element_arrayref);
use Storable qw(dclone);

=attribute module

[% ss.name %] holds the Pod::Plexus::Module that contains this
documentation section.

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

has name => (
	is      => 'ro',
	isa     => 'Str',
	default => "",
);

has verbose => (
	is       => 'ro',
	isa      => 'Bool',
	required => 1,
);

has docs => (
	is       => 'ro',
	isa      => 'ArrayRef[Pod::Elemental::Paragraph|Pod::Plexus::Docs]',
	required => 1,
	weak_ref => 1,
);

has docs_index => (
	is       => 'ro',
	isa      => 'Int',
	required => 1,
);

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

has doc_body => (
	is      => 'rw',
	isa     => 'ArrayRef[Pod::Elemental::Paragraph|Pod::Plexus::Docs]',
	traits  => [ 'Array' ],
	#lazy    => 1,
	default => sub { [ ] },
	handles => {
		has_body     => 'count',
		push_body    => 'push',
		unshift_body => 'unshift',
	},
);

has doc_suffix => (
	is      => 'rw',
	isa     => 'ArrayRef[Pod::Elemental::Paragraph|Pod::Plexus::Docs]',
	traits  => [ 'Array' ],
	lazy    => 1,
	default => sub { [ ] },
	handles => {
		has_suffix  => 'count',
		push_suffix => 'push',
	},
);


sub clone_prefix {
	my $self = shift;
	return dclone $self->doc_prefix();
}

sub clone_body {
	my $self = shift;
	return dclone $self->doc_body();
}

sub clone_suffix {
	my $self = shift;
	return dclone $self->doc_suffix();
}


sub as_pod_string {
	my $self = shift();
	return join "", map { $_->as_pod_string() } $self->as_pod_elementals();
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


sub create {
	my $class = shift();
	return $class->new(@_);
}


has key => (
	is      => 'ro',
	isa     => 'Str',
	lazy    => 1,
	default => sub {
		my $self = shift();
		return $self->calc_key(ref($self), $self->name());
	},
);

=attribute key

[% ss.name %] contains a reference's unique identifying key.  It calls
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

[% ss.name %] calculates a reference's unique key from three
parameters: the reference's class name, the reference's module name,
and an optional symbol within the module.  Omit the symbol to
reference the module as a whole.

[% ss.name %] may be called as a class or object method.  If the
caller has the object but not all the necessary parameters, it may be
more convenient to access the key() attribute instead.

=cut

sub calc_key {
	(undef, my ($type, $symbol)) = @_;
	$type =~ s/^Pod::Plexus::Docs:://;
	return join("\t", $type, ($symbol // "(none)"));
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
			$element->isa('Pod::Plexus::Docs') and
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


1;

__END__


has is_terminal => (
	is      => 'ro',
	isa     => 'Bool',
	default => 0,
);


sub _is_terminal_element {
	my ($self, $element) = @_;

	if ($element->isa('Pod::Elemental::Element::Generic::Command')) {

		my $command = $element->{command};

		# "=cut" is consumed.

		if ($command eq 'cut') {
			$self->push_cut();
			$self->is_terminated(1);
			return(1, 1);
		}

		# Other terminal top-level commands aren't consumed.
		# These are POD stuff that Pod::Plexus doesn't know about.
		# They do however imply "=cut".

		if ($command =~ /^head\d$/) {
			$self->push_cut();
			$self->is_terminated(1);
			return(1, 0);
		}

		return(0, 0);
	}

	# Other entities terminate this one.

	if ($element->isa('Pod::Plexus::Docs') and $element->is_terminal()) {
		$self->push_cut();
		$self->is_terminated(1);
		return(1, 0);
	}

	return(0, 0);
}


=method consume_element

[% ss.name %] is called for the Pod::Elemental elements immediately
following the one that caused this reference to be created.  While
those trailing elements belong to this one, they should be added to
this reference's documentation.  [% ss.name %] returns true for as
long as the elements are part of this reference.  The parser will stop
looking for new documentation after the first false return value.

[% mod.name %] implements the base method to do nothing and return
false immediately.

=cut

sub consume_element {
	my ($self, $element) = @_;
	return 0;
}


sub _build_documentation {
	return [ ];
}





=attribute definition_package

[% ss.name %] contains the package the reference was invoked in.

=cut

has definition_package => (
	default => sub { my $self = shift(); $self->module_package(); },
	is      => 'ro',
	isa     => 'Str',
	lazy    => 1,
);


=attribute definition_file

[% ss.name %] contains the path of the file invoking this reference.

=cut

has definition_file => (
	default => sub { my $self = shift(); $self->module_path(); },
	is      => 'ro',
	isa     => 'Str',
	lazy    => 1,
);


=attribute definition_line

[% ss.name %] contains the line number of this reference's invocation.

=cut

has definition_line => (
	default => sub { my $self = shift(); $self->node()->start_line(); },
	is      => 'ro',
	isa     => 'Int',
	lazy    => 1,
);


=attribute symbol

[% ss.name %] optinally references a particular symbol in the module
being referenced.  If omitted, the reference will apply to the target
module() as a whole.

=cut

has symbol => (
	default => sub {
		my $self = shift;
		confess "$self symbol's default must be overridden";
	},
	is      => 'rw',
	isa     => 'Str',
	lazy    => 1,
);


=method is_local

[% ss.name %] returns true if the reference is local within the module
invoking it.

=cut

sub is_local {
	my $self = shift();
	return $self->definition_package() eq $self->module_package();
}


has distribution => (
	is       => 'ro',
	isa      => 'Pod::Plexus::Distribution',
	required => 1,
);


has module => (
	is       => 'ro',
	isa      => 'Pod::Plexus::Module',
	required => 1,
	handles  => {
		module_package => 'package',
		module_path => 'pathname',
	},
);


has node => (
	is       => 'ro',
	isa      => 'Pod::Elemental::Element::Generic::Command',
	required => 1,
);


sub resolve {
	# Virtual base method.  Does nothing by default.
}


no Moose;

1;
