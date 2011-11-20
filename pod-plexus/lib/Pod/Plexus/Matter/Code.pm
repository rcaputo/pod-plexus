package Pod::Plexus::Matter::Code;

=abstract A reference to documentation for an attribute or method entity.

=cut

use Moose;
extends 'Pod::Plexus::Matter';


use Pod::Plexus::Util::PodElemental qw(blank_line cut_paragraph);


sub is_inheritable { 1 }


sub section_body_handler { 'absorb_my_body' }


has name => (
	is      => 'ro',
	isa     => 'Str',
	default => sub {
		my $self = shift();

		my $element = $self->docs()->[ $self->docs_index() ];

		return $1 if $element->content() =~ /^\s* (\S+) \s*$/x;

		my $error = (
			"Wrong syntax: =" . $element->command() . " " . $element->content() .
			" at " . $self->module_path() .
			" line " . $element->start_line()
		);

		$self->push_error($error);
		return '(failed)';
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
