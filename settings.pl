#!/usr/bin/env perl

use feature qw(say);

use File::Basename;

use lib dirname(__FILE__);  # Import from this directory
use Flef::Settings;

sub printUsage {
  say "usage: setting.pl [setting-name]";
}

my $ARGC = @ARGV;
if ($ARGC != 1) {
  printUsage();
  exit 1;
}

my $setting = shift;
say Flef::Settings::get($setting);
