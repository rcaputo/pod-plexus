package Pod::Plexus::Matter::abstract;

=abstract Set a succinct, one-line description of the module.

=cut

use Moose;
extends 'Pod::Plexus::Matter';


use Pod::Plexus::Util::PodElemental qw(
	blank_line head_paragraph cut_paragraph
);


sub is_top_level { 1 }


has abstract => (
	is      => 'ro',
	isa     => 'Str',
	default => sub {
		my $self = shift();

		my $abstract = $self->docs()->[ $self->docs_index() ]->content();
		$abstract =~ s/^\s+//;
		$abstract =~ s/\s+$//;
		$abstract =~ s/\s+/ /g;

		return $abstract;
	},
);


has '+doc_prefix' => (
	default => sub {
		my $self = shift();
		return [
			head_paragraph(
				1,
				"NAME " . $self->module_package() . " - " . $self->abstract() . "\n"
			),
			blank_line()
		];
	},
);


has '+doc_suffix' => (
	default => sub {
		return [ blank_line(), cut_paragraph() ];
	},
);


sub BUILD {
	my $self = shift();
	$self->discard_my_section();
}


no Moose;

1;
