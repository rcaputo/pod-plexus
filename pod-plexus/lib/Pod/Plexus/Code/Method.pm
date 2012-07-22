package Pod::Plexus::Code::Method;
# TODO - Edit pass 1 done.

use Moose;
extends 'Pod::Plexus::Code';


=abstract A documentable method.

=cut


=head1 SYNOPSIS

	=head1 SOME EXAMPLES

	An example coming from the current package.

	=example method in_this_package

	An example coming from some other package:

	=example Some::Other::Package method in_another_package

	=cut

=cut


=head1 DESCRIPTION

[% m.pacakge %] determines how the "method" variant of "=example"
commands are interpreted and their resulting documentation is
rendered.

=cut


=attribute meta_entity

=include Pod::Plexus::Code attribute meta_entity

=cut

has '+meta_entity' => (
	isa => 'Class::MOP::Method',
);


# TODO - is_documented() is part of the final error checking pass.

sub _UNUSED_is_documented {
	my ($self, $module) = @_;

	my $package_name = $module->package();
	my $method_name  = $self->name();

	my $docs = $module->get_matter(
		'method',
		$method_name,
	);

	return 1 if $docs;
	return;
}


# TODO - validate() is part of the final error checking pass.

sub _UNUSED_validate {
	my ($self, $module, $errors) = @_;

	return if $self->is_documented($module);

	push @$errors, (
		$module->package() .
		" method " . $self->name() .
		" is not documented"
	);
}


no Moose;

1;
