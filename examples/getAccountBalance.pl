#!/usr/bin/perl

use strict;
use warnings;
use JSON;
use gengo::gengo;
use Data::Dumper;

# Get an instance of a mygengo client
# Sandbox
my $gengo = Gengo->new('public-key', 'private-key', 'true');

# Live
# my $gengo = Gengo->new(public-key', 'private-key', 'false');

# Retrieve basic account information...
my $balance = $gengo->getAccountBalance();

print Dumper($balance->{'response'}->{'credits'});