package Pod::Plexus::Role::Documentable;

use Moose::Role;

use Pod::Plexus::Util::PodElemental qw(blank_line);

requires '_build_documentation';

=attribute documentation

[% ss.name %] contains the Pod::Plexus documentation associated with
this code entity.

=cut

=method is_documented

[% ss.name %] returns a Boolean value indicating whether this code
entity has associated documentation.

=cut

=method push_documentation

[% ss.name %] pushes one or more Pod::Elemental::Paragraph objects
onto this entity's documentation.  Paragraphs may be commands, text,
blank lines, and anything else Pod::Elemental supports.

=cut

has documentation => (
	is      => 'rw',
	isa     => 'ArrayRef[Pod::Elemental::Paragraph|Pod::Plexus::Docs]',
	traits  => [ 'Array' ],
	lazy    => 1,
	builder => '_build_documentation',
	handles => {
		is_documented       => 'count',
		push_documentation  => 'push',
	},
);


sub push_cut {
	my $self = shift();
	$self->push_documentation(
		Pod::Elemental::Element::Generic::Command->new(
			command => "cut",
			content => "\n",
		),
	);
}

sub push_blank {
	my $self = shift();

	# TODO - Look at the last line of documentation.
	# If it's blank, don't bother pushing this blank.

	$self->push_documentation(blank_line());
}


=method cleanup_documentation

[% ss.name %] performs basic cleanup operations on documentation.  For
example, it removes leading and trailing blank lines.

It's intended to be called after the documentation for a Documentable
entity is complete.

=cut

sub cleanup_documentation {
	my $self = shift();

	my $documentation = $self->documentation();

	shift @$documentation while (
		@$documentation and $documentation->[0]->isa(
			'Pod::Elemental::Element::Generic::Blank'
		)
	);

	pop @$documentation while (
		@$documentation and $documentation->[-1]->isa(
			'Pod::Elemental::Element::Generic::Blank'
		)
	);

	# TODO - Remove contiguous blank lines?
}


sub as_pod_string {
	my $self = shift();
	return(
		join(
			"",
			map { $_->as_pod_string() }
			@{ $self->documentation() }
		)
	);
}


sub as_pod_elementals {
	my $self = shift();
	return @{$self->documentation()};
}


has is_terminated => (
	is      => 'rw',
	isa     => 'Bool',
	default => 0,
);


no Moose::Role;

1;
