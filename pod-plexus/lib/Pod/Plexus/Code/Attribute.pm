package Pod::Plexus::Code::Attribute;
# TODO - Edit pass 1 done.

use Moose;
extends 'Pod::Plexus::Code';

use Moose::Util::TypeConstraints qw(class_type);

class_type('Class::MOP::Attribute');
class_type('Moose::Meta::Role::Attribute');


=abstract A documentable class attribute.

=cut


=head1 SYNOPSIS

	=head1 SOME EXAMPLES

	An example coming from the current package:

	=example attribute in_this_package

	An example coming from some other package:

	=example Some::Other::Package attribute in_another_package

	=cut

=cut


=head1 DESCRIPTION

[% m.package %] determines how the "attribute" variant of "=example"
commands are interpreted and their resulting documentation is
rendered.

=cut


has '+meta_entity' => (
	isa => 'Class::MOP::Attribute | Moose::Meta::Role::Attribute',
);


# TODO - is_documented() is part of the final error checking pass.

sub _UNUSED_is_documented {
	my ($self, $module) = @_;

	my $package_name   = $module->package();
	my $attribute_name = $self->name();


	my $docs = $module->get_matter('attribute', $attribute_name);

	return 1 if $docs;
	return;
}


# TODO - validate() is part of the final error checking pass.

sub _UNUSED_validate {
	my ($self, $module, $errors) = @_;

	return if $self->is_documented($module);

	push @$errors, (
		$module->package() .
		" attribute " . $self->name() .
		" is not documented"
	);
}


no Moose;

1;
