#!/usr/bin/perl

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

if (0 == $ARGC) {
  printUsage();
  exit 1;
}

my $sync_action  = $ARGV[0];
my $target_arg   = $ARGV[1];
my $project_dir  = $ARGV[2];
my @command_args = @ARGV[2..$#ARGV];

if (! $target_arg) {
  say "error: SSH target not defined in arguments";
  printUsage();
  exit 1;
}

my ($target_user, $target_address, $target) = Flef::Remote::sshParseDestination($target_arg);

my $source_user = $whoami;

if (! $target_user) {
  $target_user = $whoami;
}


sub flefSyncPush {
  my @command_args = @_;
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

  my $remote_flef_dir = rtrim Flef::Remote::flefCommandString(qw/get dir/);

  if ($?) {
    my $command_status = $? >> 8;
    die "Could not determine remote flef directory. Open status: $?. Command status: $command_status. Output:\n$remote_flef_dir";
  }

  say "Remote dir: $remote_flef_dir";
  Flef::Remote::sshCommand("mkdir", "-p", $remote_flef_dir);

  if (Flef::Remote::sshCommand("test", "-d", $remote_flef_dir)) {
    die "Remote flef projects directory does not exist: $remote_flef_dir";
  }

  my $remote_project_dir = "$remote_flef_dir/$project_name";

  say "Source: $project_dir";
  say "Sending project to: $remote_project_dir";
  Flef::Remote::rsyncSendDirectory($project_dir, $remote_project_dir) == 0
    or die "Could not send project to remote host";
}


sub flefSyncPull {
  my @command_args = @_;

  # Initialize SSH and ensure flef is ready on the remote system
  #
  Flef::Remote::sshInit($target_user, $target_address);

  if (! Flef::Remote::hasFlef()) {
    say "Target doesn't have flef, cannot pull";
    exit 1;
  }

  my $flef_dir = rtrim Flef::commandString("get", "dir");
  if ($? || ! $flef_dir) {
    say "error: Cannot determine flef projects directory";
    exit ($? || 1);
  }

  # Parse args and figure out which directory to pull
  #
  my $remote_project_dir;
  my $local_project_dir;
  my $project_name;

  if (scalar @command_args == 0) {
    if ($project_dir) {
      $local_project_dir = rtrim Flef::commandString("get", "pwd");
      $project_name      = basename $local_project_dir;
    }
    else {
      say "Getting last flef project";
      @command_args = qw/last 1/;
    }
  }

  if ($command_args[0] eq "last") {
    $remote_project_dir = rtrim Flef::Remote::flefCommandString("get", @command_args);
    $project_name = basename $remote_project_dir;
    $local_project_dir = "$flef_dir/$project_name";

    if ($? || ! $remote_project_dir) {
      my $remote_get_code = $? >> 8;
      say "error: Could not get flef remote flef project. Exit code $remote_get_code. Output:\n$remote_project_dir";
      exit ($? || 1);
    }
  }

  if (! $project_name) {
    say "error: could not determine project name";
    exit 1;
  }

  say "Remote project name: $project_name";
  
  Flef::Remote::rsyncDownloadDirectory($remote_project_dir, $local_project_dir);

  exit 0;
}


if ($sync_action eq "push") {
  flefSyncPush(@command_args);
} elsif ($sync_action eq "pull") {
  flefSyncPull(@command_args);
}
else {
  say "Unrecognized sync action: $sync_action";
  printUsage;
  exit 1;
}
