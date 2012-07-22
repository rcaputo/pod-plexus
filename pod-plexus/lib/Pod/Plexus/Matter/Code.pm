package Pod::Plexus::Matter::Code;
# TODO - Edit pass 1 done.

use Moose;
extends 'Pod::Plexus::Matter';
with 'Pod::Plexus::Matter::Role::AbsorbedBody';

use Pod::Plexus::Util::PodElemental qw(blank_line cut_paragraph);


=abstract A reference to documentation for an attribute or method entity.

=cut


=head1 SYNOPSIS

TODO

=cut


=head1 DESCRIPTION

TODO

=cut


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


=after attribute doc_suffix

The POD suffix for [% m.package %] is blank.

=cut

has '+doc_suffix' => (
	default => sub {
		return [ blank_line(), cut_paragraph() ];
	},
);


no Moose;

1;
