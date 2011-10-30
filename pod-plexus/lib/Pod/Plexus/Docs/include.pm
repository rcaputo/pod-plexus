package Pod::Plexus::Docs::Include;

=abstract A reference to documentation included from elsewhere.

=cut

use Moose;
extends 'Pod::Plexus::Docs';


has '+symbol' => (
	default => "",
);


use constant POD_COMMAND  => 'include';


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

	$self->push_documentation(@{$foreign_reference->body()});
	$self->cleanup_documentation();
}


sub _parse_include_spec {
	my $self = shift();

	my %type_class = (
		'attribute' => 'Pod::Plexus::Docs::Code::Attribute',
		'method'    => 'Pod::Plexus::Docs::Code::Method',
	);

	if (
		$self->node()->{content} =~ m{
			^\s* (\S*) \s+ (attribute|method) \s+ (\S.*?) \s*$
		}x
	) {
		return($1, $type_class{$2}, $3);
	}

	if (
		$self->node()->{content} =~ m!^\s* (attribute|method) \s+ (\S.*?) \s*$!x
	) {
		return($self->module_package(), $type_class{$1}, $2);
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
