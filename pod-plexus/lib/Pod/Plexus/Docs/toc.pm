package Pod::Plexus::Docs::toc;

=abstract A reference to a dynamically generated module index.

=cut

use Moose;
extends 'Pod::Plexus::Docs';

use Pod::Plexus::Util::PodElemental qw(
	head_paragraph
	blank_line
	text_paragraph
);


has header_level => (
	is      => 'rw',
	isa     => 'Int',
	default => 2,
);

has referents => (
	is      => 'rw',
	isa     => 'ArrayRef[Pod::Plexus::Module]',
	default => sub { [ ] },
);


has '+doc_body' => (
	lazy    => 1,
	default => sub {
		my $self = shift();
		return [
			map {
				my $package  = $_->package();
				my $abstract = $_->abstract() // "(no abstract defined)";

				(
					head_paragraph($self->header_level(), "\n"),
					blank_line(),
					text_paragraph("L<$package|$package> - $abstract\n"),
					blank_line(),
				);
			}
			@{$self->referents()}
		];
	},
);


sub BUILD {
	my $self = shift();

	my $element = $self->docs()->[ $self->docs_index() ];
	my $content = $element->content();

	my $header_level = ($content =~ s/^\s*(\d+)\s*//) ? $1 : 2;

	(my $regexp = $content)  =~ s/\s+//g;

	unless (length $regexp) {
		$self->push_error(
			"=" . $element->command() . " command needs a regexp" .
			" at " . $self->module_path() .
			" line " . $self->node()->start_line()
		);
		return;
	}

	my @referents = (
		map {
			my $referent = $self->module_distribution()->get_module($_);
			my @errors = $referent->cache_structure();
			$self->push_error(@errors) if @errors;
			$referent;
		}
		sort
		grep /$regexp/,
		$self->module_distribution()->get_known_module_names()
	);

	unless (@referents) {
		$self->push_error(
			"=toc ", $element->content(), " ... doesn't match anything" .
			" at " . $self->module_path() .
			" line " . $element->start_line()
		);
		return;
	}

	$self->referents(\@referents);
}


no Moose;

1;
