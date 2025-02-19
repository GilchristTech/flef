package Flef;

use File::Basename;
use Cwd 'abs_path';


# Detect the flef installation
#
our $installation_dir = `\$SHELL -ic 'flef get installation'`;
chomp $installation_dir;

if ($? != 0 || ! $installation_dir) {
  die "Could not get flef installation directory";
}


sub commandString {
  my $flef_fh;
  my $flef_output = open($flef_fh, "-|", "$installation_dir/flef.sh", @_);
  my @output_lines = <$flef_fh>;
  close($flef_fh);
  return join("", @output_lines);
}


1;
