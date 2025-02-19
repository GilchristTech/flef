package Flef::Settings;

use feature qw(say);

use Env;
use File::Basename;

my $settings_raw;
my %settings;
my $settings_loaded = 0;

sub loadSettings {
  if ($settings_loaded) {
    return;
  }

  my $installation_dir = dirname(dirname(__FILE__));
  $settings_raw = `\$SHELL -ic "$installation_dir/eval-settings.sh" 2> /dev/null`;
  my $status = $?;

  if ($status || ! $settings_raw) {
    die "Error: could not get settings (error code: $status)";
    exit $status;
  }

  while ($settings_raw =~ /^__FLEF_SETTING__\t(\w+)\t(.*)\n*$/mg) {
    $settings{$1} = $2;
  }
}

sub get {
  my $setting_key = shift;

  loadSettings();

  if (exists $ENV{$setting_key}) {
    return $ENV{$setting_key};
  }

  if (exists $settings{$setting_key}) {
    return $settings{$setting_key};
  }

  die "Setting with key \"$setting_key\" does not exist";
}

1;
