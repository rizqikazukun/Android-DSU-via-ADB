#!/bin/sh
if [[ $(7z | awk '/7-Zip/' | cut -b -5) == "7-Zip" ]]; then
  echo "7z - OK"

  return 0
else
  echo "7z is not installed "
  return 
fi

if [[ $(adb --version | awk '/Android/' | cut -b -7) == "Android" ]]; then
  echo "Adb - OK"
else
  echo "Adb is not installed"
  return
fi

echo "How Much Data Partition You Need [GB]:"
read dsu_data
echo "Partition Data is : $dsu_data GB"

echo "Do You Using SDCard? [y/n]"
read umount_sd

# Validation for Imput file
if [[ $(ls -l ./input_file/*.img | cut -d ' ' -f 10 | wc -l) == 1 ]]; then
  echo "Image OK"
else
  echo "Error"
  echo "There is Nothing or There are more than one image"
  echo "Just Input one image"
  return
fi


startInstall() {
  # unmount sdcard
  if [[ $umount_sd == y ]] || [[ $umount_sd == Y ]]; then
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
    -n com.android.dynsystem/com.android.dynsystem.VerificationActivity \
    -a android.os.image.action.START_INSTALL \
    -d file:///storage/emulated/0/Download/$FileName.gz \
    --el KEY_SYSTEM_SIZE $(du -b $FolderInput$FileName.img | cut -f1) \
    --el KEY_USERDATA_SIZE $(($dsu_data * 1073741824))

  echo "DSU installation activity has been started!"

  # remount sdcard
  if [[ $umount_sd == true ]]; then
    echo "Remounting sdcard in 60 secs.."
    nohup $(sleep 60 && sm mount $SDCARD) >/dev/null 2>&1 &
  fi
}

FolderInput=$(echo "./input_file/")
FolderOutput=$(echo "./output_file/")
FileName=$(ls -l ./input_file/*.img | cut -d '/' -f 3 | sed "s|.img||g")

# Compressing Image
if [[ $(ls -l $FolderOutput$FileName.gz | wc -l) != 1 ]]; then
  # compress
  echo "Compressing Image - Just Wait it need a time"
  7z a -tgzip $FolderOutput$FileName.gz $FolderInput$FileName.img
else
  # pushing compressed image to download folder
  CopiedImage=$(echo "/storage/emulated/0/Download/$FileName.gz")
  if [[ $(adb shell ls $CopiedImage) == $CopiedImage ]]; then
    startInstall;
  else
    echo "Copying Image to phone"
    adb push $FolderOutput$FileName.gz /storage/emulated/0/Download/
    startInstall;
  fi
fi

# move to history
his_folder=$(logname)-$(date '+%Y-%m-%d-%H-%M-%S')
mkdir -p ./history/$his_folder
mv ./input_file/* ./history/$his_folder/
mv ./output_file/* ./history/$his_folder/



