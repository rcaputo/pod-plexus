package Pod::Plexus::Matter::include;

# TODO - Edit pass 0 done.

=abstract Include documentation from another section or boilerplate.

=cut

=head1 SYNOPSIS

To include an attribute's documentation from another package:

	=include Pod::Plexus::Cli attribute verbose

To include an attribute's documentation from this package, or from a
base class or role's package:

	=include attribute verbose

To include a method's documentation from another package:

	=include Pod::Plexus::Cli method run

To include a method's documentation from this package, or from a base
class or role's package:

	=include method run

To expand a boilerplate defined in another package:

	=include Pod::Plexus::Matter boilerplate please_report_questions

To expand a boilerplate defined from the current package, for from a
base class or role's package:

	=include boilerplate section_body_handler

=cut

=head1 DESCRIPTION

[% m.package %] includes the text of a section that was defined
elsewhere.  Sections can be method documentation, attribute
documentation, boilerplates or other things in the future.

Including documentation is similar to inheriting it (via "=inherits",
"=before" or "=after").  Included documentation doesn't come with the
original prefix and suffix.  It's only the contents of "doc_body".

=include boilerplate please_report_questions

=cut

use Moose;
extends 'Pod::Plexus::Matter::Reference';
with 'Pod::Plexus::Matter::Role::HasNoBody';

use Pod::Plexus::Matter::attribute;
use Pod::Plexus::Matter::method;


=after method is_top_level

[% m.package %] is not a top-level container.  [% s.name %]() is
false.

=cut

sub is_top_level { 0 }


sub BUILD {
	my $self = shift();

	my $element = $self->docs()->[ $self->docs_index() ];
	my $content = $element->content();

	my ($module_name, $referent_type, $referent_name);

	if (
		$content =~ m{
			^\s* (\S+) \s+ ([a-z\d]+) \s+ (\S+) \s*$
		}x
	) {
		($module_name, $referent_type, $referent_name) = (
			$1, "Pod::Plexus::Matter::$2", $3
		);
	}
	elsif ($content =~ m/^\s* ([a-z\d]+) \s+ (\S+) \s*$/x) {
		($module_name, $referent_type, $referent_name) = (
			$self->module_package(), "Pod::Plexus::Matter::$1", $2
		);
	}
	else {
		die [
			"Wrong syntax" .
			" in '=" . $element->command() . " $content'" .
			" at " . $self->module_pathname() .
			" line " . $element->start_line()
		];
	}

	my $referent = $self->get_referent_matter(
		$module_name, $referent_type, $referent_name
	);

	$self->name($referent_name);
	$self->referent($referent);
	$self->doc_body($referent->clone_body());

	return;
}


no Moose;

1;
