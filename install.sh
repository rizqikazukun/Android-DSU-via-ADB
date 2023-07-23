#!/bin/sh
FolderInput=$(echo "./input_file/")
FolderOutput=$(echo "./output_file/")
FileName=$(ls -l ./input_file/*.img | cut -d '/' -f 3 | sed "s|.img||g")

# create process.log
if [[ $(ls -l *.log | cut -d ' ' -f 9) == "" ]]; then
  touch ./process.log
  echo "Installation Proccess" >>./process.log
  echo "$(date '+%Y%m%d%H%M%S') Attempt=1" >>./process.log
else
  Att=$(cat ./process.log | grep Attempt | sort -r | head -1 | cut -d ' ' -f 2 | cut -c 9)
  let AttP=$Att+1
  echo "$(date '+%Y%m%d%H%M%S') Attempt=$AttP" >>./process.log
fi

# Validation For Dependency
# 7z
if [[ $(7z | awk '/7-Zip/' | cut -b -5) == "7-Zip" ]]; then
  echo "7z - OK"
  echo "$(date '+%Y%m%d%H%M%S') 7z=1" >>./process.log
else
  echo "7z is not installed "
  echo "$(date '+%Y%m%d%H%M%S') 7z=0" >>./process.log
  return
fi

# Validation For Dependency
# adb
if [[ $(adb --version | awk '/Android/' | cut -b -7) == "Android" ]]; then
  echo "Adb - OK"
  echo "$(date '+%Y%m%d%H%M%S') Adb=1" >>./process.log
else
  echo "Adb is not installed"
  echo "$(date '+%Y%m%d%H%M%S') Adb=0" >>./process.log
  return
fi

# Validation for Input file
if [[ $(ls -l ./input_file/*.img | cut -d ' ' -f 10 | wc -l) == 1 ]]; then
  echo "Image OK"
  echo "$(date '+%Y%m%d%H%M%S') Img=1" >>./process.log
  echo "$(date '+%Y%m%d%H%M%S') ImgCount=$(ls -l ./input_file/*.img | cut -d ' ' -f 10 | wc -l)" >>./process.log
else
  echo "Error"
  echo "There is Nothing or There are more than one image"
  echo "Just Input one image"
  echo "$(date '+%Y%m%d%H%M%S') Img=0" >>./process.log
  echo "$(date '+%Y%m%d%H%M%S') ImgCount=$(ls -l ./input_file/*.img | cut -d ' ' -f 10 | wc -l)" >>./process.log
  return
fi

# Question for dsu user data partition size
if [[ $(cat ./process.log | grep DataPartition | sort -r | head -1 | cut -d '=' -f 2) == "" ]]; then
  echo "How Much Data Partition You Need [GB]:"
  read dsu_data
  echo "Partition Data is : $dsu_data GB"
  echo "$(date '+%Y%m%d%H%M%S') DataPartition=$dsu_data" >>./process.log
else
  dsu_data=$(cat ./process.log | grep DataPartition | sort -r | head -1 | cut -d '=' -f 2)
  echo "Partition Data is : $dsu_data GB"
  echo "$(date '+%Y%m%d%H%M%S') DataPartition=$dsu_data" >>./process.log
fi

# Question for sdcard Options
if [[ $(cat ./process.log | grep SDCard | sort -r | head -1 | cut -d '=' -f 2) == "" ]]; then
  echo "Do You Using SDCard? [y/n]"
  read umount_sd
  echo "$(date '+%Y%m%d%H%M%S') SDCard=$umount_sd" >>./process.log
  echo "Sdcard Options is : $umount_sd"
else
  umount_sd=$(cat ./process.log | grep SDCard | sort -r | head -1 | cut -d '=' -f 2)
  echo "$(date '+%Y%m%d%H%M%S') SDCard=$umount_sd" >>./process.log
  echo "Sdcard Options is : $umount_sd"
fi

startInstall() {

  # unmount sdcard
  if [[ $umount_sd == y ]] || [[ $umount_sd == Y ]]; then
    SDCARD=$(adb shell sm list-volumes | grep -v null | grep public)
    if [[ $SDCARD == "" ]]; then
      echo "Unmount SD card option is enabled, but there is no sdcard detected, skipping.."
      echo "$(date '+%Y%m%d%H%M%S') Unmount SD card option is enabled, but there is no sdcard detected, skipping.." >>./process.log
      umount_sd=false
    else
      echo "Unmount SD card option is enabled, sdcard will be ejected temporary, preventing DSU allocation on SD.."
      echo "$(date '+%Y%m%d%H%M%S') Unmount SD card option is enabled, sdcard will be ejected temporary, preventing DSU allocation on SD.." >>./process.log
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
    echo "$(date '+%Y%m%d%H%M%S') Remounting sdcard in 60 secs.." >>./process.log
    nohup $(sleep 60 && sm mount $SDCARD) >/dev/null 2>&1 &
  fi
}

# Compressing Image
if [[ $(ls -l $FolderOutput$FileName.gz | wc -l) != 1 ]]; then
  # compress
  echo "Compressing Image - Just Wait it need a time"
  echo "$(date '+%Y%m%d%H%M%S') Compressing Image - Just Wait it need a time" >>./process.log
  7z a -tgzip $FolderOutput$FileName.gz $FolderInput$FileName.img
else
  # pushing compressed image to download folder
  CopiedImage=$(echo "/storage/emulated/0/Download/$FileName.gz")
  if [[ $(adb shell ls $CopiedImage) == $CopiedImage ]]; then
    echo "$(date '+%Y%m%d%H%M%S') Image copied, then start install.." >>./process.log
    startInstall
  else
    echo "Copying Image to phone"
    echo "$(date '+%Y%m%d%H%M%S') Copying image first, then start install.." >>./process.log
    adb push $FolderOutput$FileName.gz /storage/emulated/0/Download/
    startInstall
  fi
fi

# move to history
his_folder=$(logname)-$(date '+%Y-%m-%d-%H-%M-%S')
mkdir -p ./history/$his_folder
mv ./input_file/* ./history/$his_folder/
mv ./output_file/* ./history/$his_folder/
