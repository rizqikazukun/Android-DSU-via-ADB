#!/bin/sh

echo "How Much Data Partition You Need [GB]:"  
read dsu_data
echo "Partition Data is : $dsu_data GB" 

echo "Do You Using SDCard? [y/n]"
read is_sdcard_exists


if [[ $is_sdcard_exists == y ]]
then
echo "SDCard is available [$is_sdcard_exists]"
umount_sd=true  
else
  echo "SDCard is not available [$is_sdcard_exists]"
  umount_sd=false
fi

# compress 
echo "Compressing Image - Just Wait it need a time"
gzip -c ./input_file/*.img > ./output_file/system_raw.gz

# pushing compressed image to download folder
echo "Copying Image to phone"
adb push ./output_file/*.gz /storage/emulated/0/Download/

# unmount sdcard
if [[ $umount_sd == true ]]; then
  SDCARD=$(adb shell sm list-volumes | grep -v null | grep public)
  if [[ $SDCARD == "" ]]; then
    echo "Unmount SD card option is enabled, but there is no sdcard detected, skipping.."
    umount_sd=false
  else
    echo "Unmount SD card option is enabled, sdcard will be ejected temporary, preventing DSU allocation on SD.."
    sm unmount $SDCARD
  fi
fi

# required prop
adb shell setprop persist.sys.fflag.override.settings_dynamic_system true

# invoke DSU activity
adb shell am start-activity \
-n com.android.dynsystem/com.android.dynsystem.VerificationActivity  \
-a android.os.image.action.START_INSTALL  \
-d file:///storage/emulated/0/Download/system_raw.gz  \
--el KEY_SYSTEM_SIZE $(du -b ./input_file/*.img|cut -f1)  \
--el KEY_USERDATA_SIZE $(($dsu_data*1073741824))

echo "DSU installation activity has been started!"

# remount sdcard
if [[ $umount_sd == true ]]; then
  echo "Remounting sdcard in 60 secs.."
  nohup $(sleep 60 && sm mount $SDCARD) >/dev/null 2>&1 &
fi

# move to history
his_folder=$(logname)-$(date '+%Y-%m-%d-%H-%M-%S')
mkdir -p ./history/$his_folder
mv ./input_file/* ./history/$his_folder/
mv ./output_file/* ./history/$his_folder/
