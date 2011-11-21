package Pod::Plexus::Matter::Code;

# TODO - Edit pass 0 done.

=abstract A reference to documentation for an attribute or method entity.

=cut

use Moose;
extends 'Pod::Plexus::Matter';
with 'Pod::Plexus::Matter::Role::AbsorbedBody';


use Pod::Plexus::Util::PodElemental qw(blank_line cut_paragraph);


has name => (
	is      => 'ro',
	isa     => 'Str',
	default => sub {
		my $self = shift();

		my $element = $self->docs()->[ $self->docs_index() ];

		return $1 if $element->content() =~ /^\s* (\S+) \s*$/x;

		chomp(my $content = $element->content());
		die [
			"Wrong syntax" .
			" in '=" . $element->command() . " $content'" .
			" at " . $self->module_pathname() .
			" line " . $element->start_line()
		];
	},
);


# TODO - This tends to be common.
# How about abstracting it?
# Defining it as the default value in the base class?

has '+doc_suffix' => (
	default => sub {
		return [ blank_line(), cut_paragraph() ];
	},
);


no Moose;

1;
