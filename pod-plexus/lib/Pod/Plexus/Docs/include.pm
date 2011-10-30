package Pod::Plexus::Docs::include;

=abstract A reference to documentation included from elsewhere.

=cut

use Moose;
extends 'Pod::Plexus::Docs';

use Pod::Plexus::Docs::attribute;
use Pod::Plexus::Docs::method;

has '+symbol' => (
	default => "",
);


sub BUILD {
	my $self = shift();

	my ($module, $type, $symbol) = $self->_parse_include_spec();

	return unless $module;

	my $foreign_module = $self->distribution()->get_module($module);
	$foreign_module->prepare_to_render($self->errors());
	return if @{$self->errors()};

	my $foreign_reference = $foreign_module->get_documentation(
		$type, $module, $symbol
	);
use Carp qw(confess); confess("erm") unless defined $foreign_reference;
	$self->push_documentation(@{$foreign_reference->body()});
	$self->cleanup_documentation();
}


sub _parse_include_spec {
	my $self = shift();

	if (
		$self->node()->{content} =~ m{
			^\s* (\S*) \s+ (attribute|method) \s+ (\S.*?) \s*$
		}x
	) {
		return($1, "Pod::Plexus::Docs::$2", $3);
	}

	if (
		$self->node()->{content} =~ m!^\s* (attribute|method) \s+ (\S.*?) \s*$!x
	) {
		return($self->module_package(), "Pod::Plexus::Docs::$1", $2);
	}

	push @{$self->errors()}, (
		"Wrong inclusion syntax: =include " . $self->node()->{content} .
		" at " . $self->module_path() .
		" line " . $self->node()->{start_line}
	);

	return;
}


no Moose;

1;
