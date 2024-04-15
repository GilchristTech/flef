#!/usr/bin/perl

use strict;
use warnings;
use File::Temp qw(tempdir);
use File::Basename;

use feature qw(say);

my $installation_dir = dirname(__FILE__);
chomp (my $whoami = `whoami`);

my $tmp_dir;
my $ssh_config_path;
my $ssh_socket;

sub printUsage {
  say "sync.pl [target]"
}

#
# Parse arguments
#

if (scalar @ARGV != 1) {
  printUsage;
  exit 1;
}

my $target_arg = $ARGV[0];

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

my $target = "$target_user\@$target_address";

# Create the SSH configuration

$tmp_dir         = tempdir(CLEANUP => 1);
$ssh_config_path = "$tmp_dir/ssh-cfg";
$ssh_socket      = "$tmp_dir/ssh-socket";

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


sub sshCmd {
  my @args = @_;

  return system(
    "ssh",
    "-F", $ssh_config_path,
    "-l", $target_user,
    $target_address,
    @_
  ) >> 8;
}


sub rsyncSend {
  my $src  = shift . "/";
  my $dest = $target.":".shift;

  return system(
    "rsync",
    "--delete-after",
    "-zarP",  # compress, archive, recursive, Progress
    "-e", "ssh -F $ssh_config_path",
    $src, $dest
  ) >> 8;
}


sub flefRemoteInstall {
  rsyncSend($installation_dir, "~/.flef");

  # Replace reference's to the local user's home directory with
  # references to the target's home directory

  if (sshCmd("test", "-f", "~/.flef/flef.config.sh") == 0) {
    say "Adjusting remote flef configuration";

    my $find    = '/home/'.$source_user.'/';
    my $replace = '/home/'.$target_user.'/';

    sshCmd('sed', '-i', "s:$find:$replace:g", '~/.flef/flef.config.sh');
  }

  sshCmd("~/.flef/install.sh", "--yes");
}

# Check whether flef is installed on the remote target, and if not, install
#

my $type_flef = sshCmd("(\$SHELL -ic 'type flef') 2> /dev/null 1> /dev/null");

if ($type_flef == 0) {
  say "Target host and user has flef installed";
}
else {
  say "Target doesn't have flef";
  flefRemoteInstall();
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
