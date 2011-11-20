package Pod::Plexus::Matter::toc;

# TODO - Edit pass 0 done.

=abstract Generate a table of contents for modules that match a regexp.

=cut

use Moose;
extends 'Pod::Plexus::Matter';
with 'Pod::Plexus::Matter::Role::PrependToBody';

use Pod::Plexus::Util::PodElemental qw(
	generic_command
	blank_line
	text_paragraph
);


has referents => (
	is      => 'rw',
	isa     => 'ArrayRef[Pod::Plexus::Module]',
	default => sub { [ ] },
);


has '+doc_prefix' => (
	default => sub {
		[
			generic_command("over", "4\n"),
			blank_line(),
		]
	},
);


has '+doc_suffix' => (
	default => sub {
		[
			generic_command("back", "\n"),
			blank_line(),
		]
	}
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
					generic_command("item", "L<$package|$package> - $abstract\n"),
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
	chomp $content;

	(my $regexp = $content)  =~ s/\s+//g;

	unless (length $regexp) {
		die [
			"'=" . $element->command() . "' command needs a regexp" .
			" at " . $self->module_pathname() .
			" line " . $element->start_line()
		];
	}

	my @referents = (
		map {
			my $referent = $self->module_distribution()->get_module($_);
			my @errors = $referent->cache_structure();
			die \@errors if @errors;
			$referent;
		}
		sort
		grep /$regexp/,
		$self->module_distribution()->get_known_module_names()
	);

	unless (@referents) {
		die [
			"'=" . $element->command() . " $content' doesn't match anything" .
			" at " . $self->module_pathname() .
			" line " . $element->start_line()
		];
	}

	$self->referents(\@referents);
}


no Moose;

1;
