package Pod::Plexus::Matter::function;

# TODO - Edit pass 0 done.

=abstract Document a package function.

=cut


=head1 SYNOPSIS

	=function blank_line

	Prose describing the blank_line() function.

	=cut

=cut


=head1 DESCRIPTION

"=function" describes a function in the current package.  It behaves
almost exactly like "=method", but its symbols exist within a
different namespace.  Pod::Weaver to gather functions into a different
section than methods, and Pod::Plexus can tell the difference between
functions and methods.

=cut


use Moose;
extends 'Pod::Plexus::Matter::Code';

use Pod::Plexus::Util::PodElemental qw(generic_command blank_line);


sub is_top_level { 1 }


has '+doc_prefix' => (
	default => sub {
		my $self = shift();
		return [
			generic_command("function", $self->name() . "\n"),
			blank_line(),
		];
	},
);


no Moose;

1;
