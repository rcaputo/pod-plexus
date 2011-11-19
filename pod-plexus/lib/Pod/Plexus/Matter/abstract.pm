package Pod::Plexus::Matter::abstract;

=abstract Set a succinct, one-line description of the module.

=cut

=head1 SYNOPSIS

	=abstract Set a succinct, one-line description of the module.

=cut

=head1 DESCRIPTION

[% m.name %] defines how [% d.name %] will parse "=abstract" meta-POD
and generate the resulting POD documentation.

=cut

use Moose;
extends 'Pod::Plexus::Matter';


use Pod::Plexus::Util::PodElemental qw(
	blank_line head_paragraph cut_paragraph
);


sub is_top_level { 1 }


=attribute abstract

The "[% s.name %]" attribute holds the abstract text used to build a
module's "=head1 NAME" section.  This value is also used by other
modules when cross referencing modules.

=cut

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
