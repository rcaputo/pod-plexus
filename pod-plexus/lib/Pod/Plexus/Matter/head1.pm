package Pod::Plexus::Matter::head1;

# TODO - Edit pass 0 done.


=abstract Add Pod::Plexus semantics to plain POD head1 sections.

=cut


=head1 SYNOPSIS

	=head1 SYNOPSIS

		=head1 SYNOPSIS

			...

		=cut

	=cut

=cut


=head1 DESCRIPTION

POD "=head1" sections tend to be important.  [% m.package %] parses
them so Pod::Plexus can analyze and validate them.  For example,
Pod::Plexus expects every module to include a "=head1 SYNOPSIS" and
"=head1 DESCRIPTION".  It couldn't verify their presence without this
module.

=cut


use Moose;
extends 'Pod::Plexus::Matter::Pod';
with 'Pod::Plexus::Matter::Role::AbsorbedBody';

use Pod::Plexus::Util::PodElemental qw(
	blank_line head_paragraph cut_paragraph
);


sub is_top_level { 1 }


has '+doc_suffix' => (
	default => sub {
		return [ blank_line(), cut_paragraph() ];
	},
);


sub BUILD {
	my ($self, $args) = @_;
	my $content = $self->element()->content();

	my $name = $content;
	$name =~ s/^\s+//;
	$name =~ s/\s+$//;
	$name =~ s/\s+/_/g;
	$self->name($name);

	$self->doc_prefix(
		[
			head_paragraph(1, $content),
			blank_line(),
		]
	);
}


no Moose;

1;
