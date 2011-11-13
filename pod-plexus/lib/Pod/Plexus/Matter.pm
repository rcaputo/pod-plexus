package Pod::Plexus::Matter;

=abstract A generic expandable documentation reference.

=head1 SUBCLASSES

=toc 2 ^Pod::Plexus::Matter::

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
	isa      => 'ArrayRef[Pod::Elemental::Paragraph|Pod::Plexus::Matter]',
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


no Moose;

1;
