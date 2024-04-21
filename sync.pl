#!/usr/bin/perl

use v5.38;
use feature qw(say);

use File::Basename;

use lib dirname(__FILE__);  # Import from this directory
use Flef;
use Flef::Remote;

sub rtrim {
  return $_[0] =~ s/\s+$//rg;
}

my $whoami = rtrim `whoami`;

if ($? || ! $whoami) {
  die "Error: could not determine user, `whoami` exited with code $?";
}


sub printUsage {
  say "usage: flef sync [push|pull] [target] [project]?"
}

#
# Parse arguments
#

my $ARGC = @ARGV;

if (0 == $ARGC || $ARGC > 3) {
  printUsage;
  exit 1;
}

my $sync_action = $ARGV[0];
my $target_arg  = $ARGV[1];
my $project_dir = $ARGV[2];

my ($target_user, $target_address, $target) = Flef::Remote::sshParseDestination($target_arg);

my $source_user = $whoami;

if (! $target_user) {
  $target_user = $whoami;
}

if (! $project_dir) {
  $project_dir = rtrim Flef::commandString("get", "pwd");
}

# Get flef project path and name
#
my $project_name = basename "$project_dir";
say "Project name: $project_name";

if ($?) {
  say "$project_dir";
  exit $?;
}

# If the project directory is a symbolic link, resolve it
#
if (-l $project_dir) {
  use Cwd 'abs_path';
  $project_dir = abs_path $project_dir;
}


if ($sync_action eq "push") {
  # Check for a flef installation on the target host, and install if it's not
  # present.

  Flef::Remote::sshInit($target_user, $target_address);

  if (Flef::Remote::hasFlef()) {
    say "Target host and user has flef installed";
  }
  else {
    say "Target doesn't have flef";
    Flef::Remote::installFlef();
  }

  # Transfer project
  #

  my $remote_flef_dir = rtrim Flef::Remote::sshCommandString(
    "(\$SHELL -ic 'flef get dir') 2> /dev/null"
  );

  if ($?) {
    my $command_status = $?;
    die "Could not determine remote flef directory. Open status: $?. Command status: $command_status. Output:\n$remote_flef_dir";
  }

  say "Remote dir: $remote_flef_dir";
  Flef::Remote::sshCommand("mkdir", "-p", $remote_flef_dir);
  exit;

  if (Flef::Remote::sshCommand("test", "-d", $remote_flef_dir)) {
    die "Remote flef projects directory does not exist: $remote_flef_dir";
  }

  my $remote_project_dir = "$remote_flef_dir/$project_name";

  say "Source: $project_dir";
  say "Sending project to: $remote_project_dir";
  Flef::Remote::rsyncSendDirectory($project_dir, $remote_project_dir) == 0
    or die "Could not send project to remote host";
}
elsif ($sync_action eq "pull") {
  Flef::Remote::sshInit($target_user, $target_address);
  say "Pull action currently unimplemented";
  exit 1;
}
else {
  say "Unrecognized sync action: $sync_action";
  printUsage;
  exit 1;
}
