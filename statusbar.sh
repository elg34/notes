# Modified from https://unix.stackexchange.com/questions/473788/simple-swaybar-example
# by lui

# The Sway configuration file in ~/.config/sway/config calls this script.
# You should see changes to the status bar after saving this script.
# If not, do "killall swaybar" and $mod+Shift+c to reload the configuration.

# The abbreviated weekday (e.g., "Sat"), followed by the ISO-formatted date
# like 2018-10-06 and the time (e.g., 14:01). Check `man date` on how to format
# time and date.
date_formatted=$(date "+%a %F %H:%M")

# "upower --enumerate | grep 'BAT'" gets the battery name (e.g.,
# "/org/freedesktop/UPower/devices/battery_BAT0") from all power devices.
# "upower --show-info" prints battery information from which we get
# the state (such as "charging" or "fully-charged") and the battery's
# charge percentage. With awk, we cut away the column containing
# identifiers. i3 and sway convert the newline between battery state and
# the charge percentage automatically to a space, producing a result like
# "charging 59%" or "fully-charged 100%".
battery_info=$(upower --show-info $(upower --enumerate |\
grep 'BAT') |\
egrep "state|percentage" |\
awk '{print $2}')

# get current volume
audio_volume=$(pamixer --get-volume-human)

# get brightness level
brightness_level=$(xbacklight -get)

# Additional emojis and characters for the status bar:
# Electricity: ⚡ ↯ ⭍
# Audio: 🔈 🔊 🎧 🎶 🎵
# Separators: \| ❘ ❙ ❚
# Misc: 💻 ⭐ ↑ ↓ ✉ 
# Light: ☀🌣☼
echo "🔈" $audio_volume \| "⚡" $battery_info \| "☀" $brightness_level"%" \| $date_formatted
