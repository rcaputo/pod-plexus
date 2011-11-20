#!/usr/bin/env perl

# TODO - Edit pass 0 done.

# PODNAME: podplexus.pl

use warnings;
use strict;
use Pod::Plexus::Cli;

exit Pod::Plexus::Cli->new_with_options()->run();
