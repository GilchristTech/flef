package Flef::Remote;

use feature qw(say);
use File::Temp qw(tempdir);
use Flef;

our $tmp_dir;
our $ssh_config_path;
our $ssh_socket;

our $ssh_user;
our $ssh_address;
our $ssh_destination;

our $ssh_home;

chomp(my $whoami = `whoami`);


sub sshParseDestination {
  my $num_args = scalar @_;

  if ($num_args < 1 || $num_args > 2) {
    die "parseTarget requires one or two arguments, got $num_args";
  }

  my $user;
  my $address;

  if ($num_args == 1) {
    # Parse target user and address

    if ($_[0] =~ m/(?:([\w.-_]+)@)?([\w.-_:]+)/i) {
      $user    = $1;
      $address = $2;
    }
    else {
      die "Could not parse SSH destination: "
    }
  }
  elsif ($num_args == 2) {
    $user    = $_[0];
    $address = $_[1];
  }

  # If the user is not defined, go with the current one
  #
  chomp($user = $user || `whoami`);

  my $destination = "$user\@$address";
  return $user, $address, $destination;
}


sub sshInit {
  $ssh_user        = shift;
  $ssh_address     = shift;
  $ssh_destination = $ssh_user.'@'.$ssh_address;
  say "$ssh_destination";

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

  system("chmod", "600", $ssh_config_path) == 0
    or die "Could not set SSH config permissions: $!";

  # Establish SSH tunnel

  system(
    "ssh",
    "-F", $ssh_config_path,
    "-f", # Go to background
    "-N", # Don't execute a command
    "-l", $ssh_user,
    $ssh_address
  ) == 0 or die "Failed to establish SSH tunnel: $!";

  $ssh_home = sshCommandString(qw/bash -c 'cd && pwd'/);
  chomp $ssh_home;

  if (! $ssh_home) {
    die "Could not determine user home directory";
  }
}


sub sshCommand {
  my @args = @_;

  return system(
    "ssh",
    "-F", $ssh_config_path,
    "-l", $ssh_user,
    $ssh_address,
    @_
  ) >> 8;
}


sub sshCommandString {
  my @args = @_;

  my $stdout;
  open(
    $stdout, "-|",
    "ssh",
    "-F", $ssh_config_path,
    "-l", $ssh_user,
    $ssh_address,
    @_
  );

  my @output_lines = <$stdout>;
  close($stdout);

  return join("", @output_lines);
}


sub flefCommandString {
  return sshCommandString("$ssh_home/.flef/flef.sh", @_);
}


sub rsyncSendDirectory {
  my $src  = shift . "/";
  my $dest = "$ssh_destination:".shift;

  my @command = (
    "rsync",
    "--delete-after",
    "-zarP",  # compress, archive, recursive, Progress
    "-e", "ssh -F \"$ssh_config_path\"",
    $src, $dest
  );

  return system(@command) >> 8;
}


sub rsyncDownloadDirectory {
  my $src  = "$ssh_destination:".shift . "/";
  my $dest = shift;

  my @command = (
    "rsync",
    "--delete-after",
    "-zarP",  # compress, archive, recursive, Progress
    "-e", "ssh -F \"$ssh_config_path\"",
    $src, $dest
  );

  return system(@command) >> 8;
}


sub hasFlef {
  # Returns true if the remote host has flef
  #
  return sshCommand("(\$SHELL -ic 'type flef') 2> /dev/null 1> /dev/null") == 0;
}


our $installation_dir;


sub installFlef {
  my $rsync_status = rsyncSendDirectory($Flef::installation_dir, "~/.flef");
  if ($rsync_status) { return $rsync_status };

  # Replace reference's to the local user's home directory with
  # references to the target's home directory

  if (sshCommand("test", "-f", "~/.flef/flef.config.sh") == 0) {
    say "Adjusting remote flef configuration";

    my $find    = '/home/'.$whoami.'/';
    my $replace = '/home/'.$ssh_user.'/';

    my $sed_status = sshCommand('sed', '-i', "s:$find:$replace:g", '~/.flef/flef.config.sh');
    if ($sed_status) { return $sed_status };
  }

  return sshCommand("~/.flef/install.sh", "--yes");
}


sub sshClose {
  my $close_status = system(
    "ssh",
    "-F", $ssh_config_path,
    "-S", $ssh_socket,
    "-O", "exit",
    "$ssh_address",
  );

  if ($close_status) {
    return $close_status;
  }

  $tmp_dir         = undef;
  $ssh_config_path = undef;
  $ssh_socket      = undef;
  $ssh_user        = undef;
  $ssh_address     = undef;
  $ssh_home        = undef;
  return 0;
}


# Cleanup: close the SSH tunnel
#
END {
  if ($ssh_socket && -f $ssh_socket) {
    sshClose() == 0 or die "Failed to close SSH tunnel: $!";
  }
}

1;
