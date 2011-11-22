package Pod::Plexus::Matter::example;

# TODO - Edit pass 0 done.

=abstract Import code from the distribution as a documentation example.

=cut

use Moose;
extends 'Pod::Plexus::Matter::Reference';

# TODO - Too tightly coupled to subclasses here.  It shouldn't be
# necessary to enumerate them here.  Nor should it be necessary to
# enumerate their names in the new_from_element() parser.

use Pod::Plexus::Matter::example::module;
use Pod::Plexus::Matter::example::attribute;
use Pod::Plexus::Matter::example::method;
use Pod::Plexus::Matter::example::function;

use Pod::Plexus::Util::PodElemental qw(text_paragraph blank_line);

use Carp qw(confess);


=attribute referent_name

"[% s.name %]" contains the name of the subroutine, method, attribute
or other code entity being included as an example.  Subclasses may use
the value of "[% s.name %]" to find its source code.

=cut

has referent_name => (
	is  => 'ro',
	isa => 'Str',
);


has '+referent' => (
	isa => 'Pod::Plexus::Module',
);

sub is_top_level { 0 }


sub new_from_element {
	my ($matter_class, %args) = @_;

	my $element = $args{element} // confess "element required";
	my $content = $element->content();

	if ($content =~ m/^\s* (module) \s+ (\S+) \s*$/x) {
		my ($module_name, $referent_type) = ($2, $1);
		$matter_class .= "::$referent_type";
		return $matter_class->new(
			%args,
			referent_name => $module_name,
		);
	}

	if (
		$content =~ m/^\s* (\S+) \s+ (attribute|method|function) \s+ (\S+) \s*$/x
	) {
		my ($module_name, $referent_type, $referent_name) = ($1, $2, $3);
		$matter_class .= "::$referent_type";
		return $matter_class->new(
			%args,
			referent_name => $module_name,
			name          => $referent_name,
		);
	}

	if ($content =~ m/^\s* (attribute|method|function) \s+ (\S+) \s* $/x) {
		my ($referent_type, $referent_name) = ($1, $2);
		$matter_class .= "::$referent_type";
		return $matter_class->new(
			%args,
			referent_name => $args{module}->package(),
			name          => $referent_name,
		);
	}

	chomp $content;
	die [
		"Wrong syntax" .
		" in '=" . $element->command() . " $content'" .
		" at " . $args{module}->pathname() .
		" line " . $element->start_line()
	];
}


sub _is_local {
	my $self = shift();
	return $self->referent_name() eq $self->module_package();
}


=method beautify_code

[% s.name %] beautifies the code passed to it in its only parameter.
Code is expected to be a single string containing multiple lines
separated by newlines.  A string of "beautified" multiple-line code is
returned.

=cut

sub beautify_code {
	my ($self, $code) = @_;

	# TODO - PerlTidy the code?
	# TODO - The following whitespace options are personal
	# preference.  Someone should patch them to be options.

	# Convert tab indents to fixed spaces for better typography.
	$code =~ s/\t/  /g;

	# Indent two spaces.  Remove leading and trailing blank lines.
	$code =~ s/\A(^\s*$)+//m;
	$code =~ s/(^\s*$)+\Z/\n/m;
	$code =~ s/^/  /mg;

	# Code must end in a newline.
	$code =~ s/\n*$/\n/;

	return $code;
}


sub _set_example {
	my ($self, $link, $code) = @_;
	$self->doc_body(
		[
			text_paragraph($link),
			blank_line(),
			text_paragraph( $self->beautify_code($code) )
		]
	);
}

no Moose;

1;
