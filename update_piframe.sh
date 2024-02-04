#!/usr/bin/bash

# Define variables
imagedir='/absolute/path/to/image/directory' # Path to the image directory.
battery_critical_pct=5                       # Display a low battery warning below this percentage.
delay_hours=2                                # The battery RTC will be set to power on again in this many hours.

# Read critical status from battery.
# battery_pct: Battery charge percentage, integer.
battery_pct=$(echo "get battery" | nc -w 1 127.0.0.1 8423 | awk '{print $2}' | awk -F '.' '{print $1}')
# battery_charging: Indicator for whether or not the battery is currently charging, boolean.
# Note that the command for battery_charging has ~10% false positive rate.
# Because a false positive would result in pi-frame staying powered on while
# operating on battery (undersired), poll for charging status four times. If *any* values
# of false are found, battery_charging will be returned as "false".
battery_charging_4x=$(i=1; while [[ i -le 4 ]]; do echo "get battery_charging" | nc -w 1 127.0.0.1 8423 | awk '{print $2}'; ((i++)); done)
if [[ $battery_charging_4x =~ "false" ]]; then
    battery_charging="false"
else
    battery_charging="true"
fi

# Sync the date/time from the web to the pi and rtc.
echo 'rtc_web' | nc -w 1 127.0.0.1 8423 > /dev/null
battery_time=$(echo 'get rtc_time' | nc -w 1 127.0.0.1 8423 | awk '{print $2}')

# Print the date & time for logging outside journalctl.
echo $battery_time

# Raise an alert the battery is less than the critical value.
# Note that a small percentage of the time, the battery percentage cannot be read successfully.
# When that occurs, the higher-level if statement prevents a blank warning message from being generated.

if [[ ${battery_pct} -ge 1 ]]; then
    echo "Battery charge: $battery_pct %"
    if [[ $battery_pct -le $battery_critical_pct ]]; then
        warnmsg="Warning: Battery level $battery_pct %. Please recharge."
    fi
else
    echo "Battery charge: Could not be determined"
fi

# Check the remote staging server for files to update locally.
echo "Checking remote server for new photos."
rsync --delete --exclude=".*" --progress --recursive --checksum\
    remote-staging-server-address:/absolute/path/to/remote/images/ \
    /absolute/path/to/local/images
# Then back up local scripts & logs to the remote server.
echo "Checking remote server for script updates."
rsync --exclude=".*" --exclude="__pycache__/" --progress --recursive --checksum\
    remote-staging-server-address:/absolute/path/to/remote/scripts/ \
    /absolute/path/to/local/scripts

# Select a random image & call the Python script to display it.
echo "Images found: $(ls $imagedir | wc --lines)"
imagepath=$(find $imagedir -type f -name '*.jpg' \
            -or -name '*.jpeg' -or -name '*.png' \
            -or -name '*.bmp' | shuf -n 1)
echo "Selected image: $imagepath"
eval "python /absolute/path/to/local/scripts/show_image.py --message \"$warnmsg\" $imagepath"

# Schedule the next boot time for now + delay_hours.
#
rtc_time=$(echo "get rtc_time" | nc -w 1 127.0.0.1 8423 | awk '{print $2}')
alarm_old=$(echo 'get rtc_alarm_time' | nc -w 1 127.0.0.1 8423 | awk '{print $2}')
delay_seconds=$(($delay_hours * 3600))
# If there is no alarm set, or if the current setting is more than delay_hours out
# of date, set a new alarm for rtc_time + delay_hours. Otherwise, simply add
# delay_hours to the current alarm.
if [[ $(($(date -d $alarm_old +%s) + $delay_seconds)) -le $(date -d $rtc_time +%s) ]]; then
     alarm_new=$(date -d "$rtc_time+$delay_hours hour" --iso-8601=seconds)
else
     alarm_new=$(date -d "$alarm_old+$delay_hours hour" --iso-8601=seconds)
fi
echo "calculated alarm time: $alarm_new"
echo "rtc_alarm_set $alarm_new 127" | nc -w 1 127.0.0.1 8423
echo "Next scheduled boot: $(echo 'get rtc_alarm_time' | nc -w 1 127.0.0.1 8423 | awk '{print $2}')"

# Sync logs to remote staging server.
echo "Syncing logs to remote server."
rsync --progress --checksum --append /absolute/path/to/local/piframe.log \
     remote-staging-server-address:/absolute/path/to/remote/piframe.log

# Determine how many users are logged in prior to automatic shutdown.
# I.e.: Don't shut down while I'm logged in working.
user_count=$(users | wc -w)
echo "Active users found: $user_count"

# If operating on battery power (i.e.: the battery is not charging)
#  print the next scheduled boot time & power off.
if [[ $battery_charging = "false" ]]; then
     if [[ $user_count = 0 ]]; then
       echo "Powering down now."
       sleep 3
       sudo shutdown now
    fi
elif [[ $battery_charging = "true" ]]; then
    echo "Power source: Plugged in."
    echo "Power will remain on."
else
    echo "Power source: Uncertain."
    if [[ $user_count = 0 ]]; then
        echo "Powering down now."
        sleep 3
        sudo shutdown now
    fi
fi

echo "##############################"
