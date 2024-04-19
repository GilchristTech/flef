#!/usr/bin/perl

use v5.38;
use strict;
use warnings;

use File::Temp qw(tempdir);
use File::Basename;

use feature qw(say);

sub rtrim {
  return $_[0] =~ s/\s+$//rg;
}

my $installation_dir = dirname(__FILE__);
my $whoami = rtrim `whoami`;

if (! $whoami) {
  die "Error: could not determine user. `whoami` exited with code $?";
}


sub flefCommandString {
  my $flef_fh;
  my $flef_output = open($flef_fh, "-|", "$installation_dir/flef.sh", @_, "2>&1");
  my @output_lines = <$flef_fh>;
  close($flef_fh);
  return join("", @output_lines);
}


sub printUsage {
  say "usage: sync.pl [push|pull] [target] [project]?"
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

my $target_user;
my $target_address;

# Parse target user and address
#
if ($target_arg =~ m/(?:([\w.-_]+)@)?([\w.-_:]+)/i) {
  $target_user    = $1;
  $target_address = $2;
}

my $source_user = $whoami;

if (! $target_user) {
  $target_user = $whoami;
}

if (! $project_dir) {
  $project_dir = rtrim flefCommandString("pwd");
}

# Get flef project path and name
#
my $project_name = basename "$project_dir";
say "Project name: $project_name";

my $target = "$target_user\@$target_address";

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

# Create the SSH configuration

my $tmp_dir         = tempdir(CLEANUP => 1);
my $ssh_config_path = "$tmp_dir/ssh-cfg";
my $ssh_socket      = "$tmp_dir/ssh-socket";

open my $fh, '>', $ssh_config_path
  or die "Cannot open $ssh_config_path: $!";

print $fh <<"END_CFG";
Host *
  ControlMaster auto
  ControlPath $ssh_socket
END_CFG
close $fh;

# Establish SSH tunnel

system(
  "ssh",
  "-F", $ssh_config_path,
  "-f", # Go to background
  "-N", # Don't execute a command
  "-l", $target_user,
  "$target_address"
) == 0 or die "Failed to establish SSH tunnel: $!";


sub sshCommand {
  my @args = @_;

  return system(
    "ssh",
    "-F", $ssh_config_path,
    "-l", $target_user,
    $target_address,
    @_
  ) >> 8;
}


sub sshCommandString {
  my $stdout;
  open($stdout, '-|', @_);

  my @output_lines = <$stdout>;
  close($stdout);

  return join("", @output_lines);
}


sub rsyncSendDirectory {
  my $src  = shift . "/";
  my $dest = $target.":".shift;

  my @command = (
    "rsync",
    "--delete-after",
    "-zarP",  # compress, archive, recursive, Progress
    "-e", "ssh -F \"$ssh_config_path\"",
    $src, $dest
  );

  say join " ", @command;

  return system(@command) >> 8;
}


sub flefTargetHasFlef {
  return sshCommand("(\$SHELL -ic 'type flef') 2> /dev/null 1> /dev/null") == 0;
}


sub flefRemoteInstall {
  my $rsync_status = rsyncSendDirectory($installation_dir, "~/.flef");
  if ($rsync_status) { return $rsync_status };

  # Replace reference's to the local user's home directory with
  # references to the target's home directory

  if (sshCommand("test", "-f", "~/.flef/flef.config.sh") == 0) {
    say "Adjusting remote flef configuration";

    my $find    = '/home/'.$source_user.'/';
    my $replace = '/home/'.$target_user.'/';

    my $sed_status = sshCommand('sed', '-i', "s:$find:$replace:g", '~/.flef/flef.config.sh');
    if ($sed_status) { return $sed_status };
  }

  return sshCommand("~/.flef/install.sh", "--yes");
}


if ($sync_action eq "push") {
  # Check for a flef installation on the target host, and install if it's not
  # present.
  #

  if (flefTargetHasFlef) {
    say "Target host and user has flef installed";
  }
  else {
    say "Target doesn't have flef";
    flefRemoteInstall;
  }

  # Transfer project
  #

  my $remote_flef_dir = rtrim sshCommandString(
    "(\$SHELL -ic 'flef dir') 2> /dev/null"
  );

  if ($?) {
    my $command_status = $?;
    die "Could not determine remote flef directory. Open status: $?. Command status: $command_status. Output:\n$remote_flef_dir";
  }

  sshCommand("mkdir", "-p", $remote_flef_dir);

  my $remote_project_dir = "$remote_flef_dir/$project_name";

  say "Source: $project_dir";
  say "Sending project to: $remote_project_dir";
  rsyncSendDirectory($project_dir, $remote_project_dir) == 0
    or die "Could not send project to remote host";
}
elsif ($sync_action eq "pull") {
  say "Pull action unimplemented";
  exit 1;
}
else {
  say "Unrecognized sync action: $sync_action";
  printUsage;
  exit 1;
}


# Cleanup: close the SSH tunnel
#
END {
  if ($ssh_socket && -f $ssh_socket) {
    system(
      "ssh",
      "-F", $ssh_config_path,
      "-S", $ssh_socket,
      "-O", "exit",
      "$target_address",
    ) == 0 or die "Failed to close SSH tunnel: $!";
  }
}
