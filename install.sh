#!/usr/bin/env bash
dir=$(dirname "$0")

declare -a schemes
schemes=($(cd $dir/colors && echo * && cd - > /dev/null))

source $dir/src/tools.sh
source $dir/src/profiles.sh

show_help() {
  echo "Usage: install.sh [-h] [-s <scheme>] [-p <profile>]"
  echo
  echo "Options"
  echo "  -h, --help"
  echo "    Show this information"
  echo "  -s scheme, --scheme scheme, --scheme=scheme"
  echo "    Color scheme to be used (will be asked otherwise)"
  echo "  -p profile, --profile profile, --profile profile"
  echo "    Gnome Terminal profile to overwrite (will be asked otherwise)"
}

validate_scheme() {
  local profile=$1
  in_array $scheme "${schemes[@]}" || die "$scheme is not a valid scheme" 2
}

set_profile_colors() {
  local profile=$1
  local scheme=$2
  local scheme_dir=$dir/colors/$scheme

  local bg_color_file=$scheme_dir/bg_color
  local fg_color_file=$scheme_dir/fg_color
  local bd_color_file=$scheme_dir/bd_color
  local cb_color_file=$scheme_dir/cb_color
  local cf_color_file=$scheme_dir/cf_color
  local hb_color_file=$scheme_dir/hb_color
  local hf_color_file=$scheme_dir/hf_color

  if [ "$newGnome" = "1" ]
    then local profile_path=$dconfdir/$profile

    # set color palette
    dconf write $profile_path/palette "$(to_dconf < $scheme_dir/palette)"

    # set foreground, background and highlight color
    dconf write $profile_path/bold-color "'$(cat $bd_color_file)'"
    dconf write $profile_path/background-color "'$(cat $bg_color_file)'"
    dconf write $profile_path/foreground-color "'$(cat $fg_color_file)'"
    dconf write $profile_path/cursor-foreground-color "'$(cat $cf_color_file)'"
    dconf write $profile_path/cursor-background-color "'$(cat $cb_color_file)'"
    dconf write $profile_path/highlight-background-color "'$(cat $hb_color_file)'"
    dconf write $profile_path/highlight-foreground-color "'$(cat $hf_color_file)'"
    dconf write $profile_path/bold-color-same-as-fg false
    dconf write $profile_path/cursor-colors-set true
    dconf write $profile_path/highlight-colors-set true

    # make sure the profile is set to not use theme colors
    dconf write $profile_path/use-theme-colors "false"
    dconf write $profile_path/use-theme-transparency "false"

  else
    local profile_path=$gconfdir/$profile

    # set color palette
    gconftool-2 -s -t string $profile_path/palette "$(to_gconf < $scheme_dir/palette)"

    # set foreground, background and highlight color
    gconftool-2 -s -t string $profile_path/bold_color $(cat $bd_color_file)
    gconftool-2 -s -t string $profile_path/background_color \
        $(cat $bg_color_file)
    gconftool-2 -s -t string $profile_path/foreground_color \
        $(cat $fg_color_file)
    gconftool-2 -s -t string $profile_path/cursor-foreground-color $(cat $cf_color_file)
    gconftool-2 -s -t string $profile_path/cursor-background-color $(cat $cb_color_file)

    # make sure the profile is set to not use theme colors
    gconftool-2 -s -t bool $profile_path/use_theme_colors false
    gconftool-2 -s -t bool $profile_path/use-theme-transparency false

    # set highlighted color to be different from foreground color
    gconftool-2 -s -t bool $profile_path/bold_color_same_as_fg true
  fi
}

interactive_help() {
  echo
  echo -en "This script will ask you which color scheme you want, and which "
  echo -en "Gnome Terminal profile to overwrite.\n"
  echo
  echo -en "If you do not wish to overwrite any of your profiles, you should create a new "
  echo -en "profile before you run this script. However, you can reset your "
  echo -en "colors to the Gnome default, by running:\n"
  echo
  echo "    Gnome >= 3.8 dconf reset -f /org/gnome/terminal/legacy/profiles:/"
  echo "    Gnome < 3.8 gconftool-2 --recursive-unset /apps/gnome-terminal"
  echo
  echo -en "By default, it runs in the interactive mode, but it also can be "
  echo -en "run non-interactively, just feed it with the necessary options, "
  echo -en "see 'install.sh --help' for details.\n"
  echo
}

interactive_select_scheme() {
  echo "Please select a color scheme:"
  select scheme
  do
    if [[ -z $scheme ]]
    then
      die "ERROR: Invalid selection -- ABORTING!" 2
    fi
    break
  done
  echo
}

interactive_confirm() {
  local confirmation

  echo    "You have selected:"
  echo
  echo    "  Scheme:  $scheme"
  echo    "  Profile: $(get_profile_name $profile) ($profile)"
  echo
  echo    "Are you sure you want to overwrite the selected profile?"
  echo -n "(YES to continue) "

  read confirmation
  if [[ $(echo $confirmation | tr '[:lower:]' '[:upper:]') != YES ]]
  then
    die "ERROR: Confirmation failed -- ABORTING!"
  fi

  echo    "Confirmation received -- applying settings"
}

while [ $# -gt 0 ]
do
  case $1 in
    -h | --help )
      show_help
      exit 0
    ;;
    --scheme=* )
      scheme=${1#*=}
    ;;
    -s | --scheme )
      scheme=$2
      shift
    ;;
    --profile=* )
      profile=${1#*=}
    ;;
    -p | --profile )
      profile=$2
      shift
    ;;
  esac
  shift
done

if [[ -z "$scheme" ]] || [[ -z "$profile" ]]
then
  interactive_help
fi

if [[ -n "$scheme" ]]
  then validate_scheme $scheme
else
  interactive_select_scheme "${schemes[@]}"
fi

if [[ -n "$profile" ]]
  then if [ "$newGnome" = "1" ]
    then profile="$(get_uuid "$profile")"
  fi
  validate_profile $profile
else
  if [ "$newGnome" = "1" ]
    then check_empty_profile
  fi
  interactive_select_profile "${profiles[@]}"
  interactive_confirm
fi

set_profile_colors $profile $scheme
