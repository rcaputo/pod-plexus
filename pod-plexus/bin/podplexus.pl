#!/usr/bin/env perl

# PODNAME: podplexus.pl

use warnings;
use strict;
use Pod::Plexus::Cli;

exit Pod::Plexus::Cli->new_with_options()->run();
