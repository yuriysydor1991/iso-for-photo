# Copyright (c) 2020 Yuriy Sydor (yuriysydor1991@gmail.com).
# All rights reserved.
#
# Redistribution and use in source and binary forms are permitted
# provided that the above copyright notice and this paragraph are
# duplicated in all such forms and that any documentation,
# advertising materials, and other materials related to such
# distribution and use acknowledge that the software was developed
# by the kytok.org.ua. The name of the
# kytok.org.ua may not be used to endorse or promote products derived
# from this software without specific prior written permission.
# THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

#!/bin/bash

CURRENT_VERSION="0.1.4"

# знайти усі фотографії з вказаної кореневої директорії
# ітерувати через список файлів і обраховувати їх загальний розмір
# якщо досягнеться максимальний розмір iso-файлу припинити ітерування
# створити список для ISO файлу.

photo_root=""
photo_tmp=""
iso_root=""

function print_usage_and_exit ()
{
  echo -e "Usage:\n\n\t photo_sort.sh [OPTIONS]\n\n"
  echo -e "\tWhere [OPTIONS] can be:\n\n"
  echo -e "\t--help - this help message"
  echo -e "\t--iso-dest <iso_dst_dir> - destination directory for all ISO-DVD files"
  echo -e "\t--file-tmp <file_tmp_dir> - directory for temporary file storing"
  echo -e "\t--file-root <file_tmp_dir> - all source files, which You want to split for ISO DVD images, with directory hierarchy preserved"
  
  exit 0
}

# цикл розпізнавання переданих параметрів
for (( iter=$((1)) ; $iter<=$# ; ++iter ))
do

  param=${@:$iter:1}
  next_param=${@:$(($iter+1)):1}
  
  if [[ $next_param = -* ]] ; then
    next_param=
  fi
  
  case $param in
  
    --iso-dest* | -iso-dest*)
      
      if [[ "$param" = *=* ]] ; then
        iso_root=${param#*=}
      elif [[ -n $next_param ]] ; then
        iso_root=$next_param
        iter=$iter+1
      else
        echo -e "parameter must to have data: '$param'\n"
        print_usage_and_exit
      fi
    
    ;;
    
    --file-root* | -file-root*)
      
      if [[ "$param" = *=* ]] ; then
        photo_root=${param#*=}
      elif [[ -n $next_param ]] ; then
        photo_root=$next_param
        iter=$iter+1
      else
        echo -e "parameter must to have data: '$param'\n"
        print_usage_and_exit
      fi
    
    ;;
    
    --file-tmp* | -file-tmp*)
      
      if [[ "$param" = *=* ]] ; then
        photo_tmp=${param#*=}
      elif [[ -n $next_param ]] ; then
        photo_tmp=$next_param
        iter=$iter+1
      else
        echo -e "parameter must to have data: '$param'\n"
        print_usage_and_exit
      fi
    
    ;;
  
    --help* | -help*)
    
        print_usage_and_exit
      
    ;;
      
    *)
      echo -e "Unknown parameter: $param)\n"
      print_usage_and_exit 
      
    ;;
      
  esac
  
done

echo "current version: "${CURRENT_VERSION}

if [[ -z $photo_root ]]
then
  echo "No photo root directory given"
  print_usage_and_exit
fi

if [[ -z $photo_tmp ]]
then
  echo "No photo tmp directory given"
  print_usage_and_exit
fi

if [[ -z $iso_root ]]
then
  echo "No iso dest directory given"
  print_usage_and_exit
fi


echo "Files directory: '${photo_root}'"
echo "Tmp files directory: '${photo_tmp}'"
echo "ISO dest directory: '${iso_root}'"

# checking for permisions to directories

if [[ ! -w ${photo_tmp} ]]
then
  echo "NO WRITE PERMISSIONS FOR TEMPORARY FILES DIRECTORY"
  exit 1
fi

if [[ ! -w ${iso_root} ]]
then
  echo "NO WRITE PERMISSIONS FOR TEMPORARY FILES DIRECTORY"
  exit 2
fi

if [[ ! -r ${photo_root} ]]
then
  echo "NO READ PERMISSIONS FOR ROOT FILES DIRECTORY"
  exit 3
fi

#checking for genisoimage command
t=$(whereis genisoimage)
tpath=${t##*[[.colon.]]}
if [[ -z ${tpath} ]]
then
  echo 'YOU NEED TO INSTALL COMMAND "genisoimage" TO CREATE ISO DVD FILES'
  exit 13
fi

fileslisttxt="${HOME}/tmp_fileslist.txt"

fld=$(dirname fileslisttxt)

if [[ ! -w "${fld}" ]]
then
  echo "temporary file directory '${fld}' isn't writable"
  exit 14
fi

if [[ ! -e "${fileslisttxt}" ]]
then
  touch ${fileslisttxt}
fi

#creating or truncating temporary files path file
truncate --size 0 "${fileslisttxt}"

#finding all files in files root directory
find "${photo_root}" -type f -exec echo '{}' >> "${fileslisttxt}" \;

declare -i iso_csize=0
declare -i iso_size=0
declare -i photo_count=0
iso_size=$(expr 1024 \* 1024 \* 1024 \* 4 \+ 1024 \* 1024 \* 250)
photo_count=$(cat "${fileslisttxt}" | wc -l)

declare -i iter=1
declare -i jter=1
declare -i fter=0
declare -i ptf=1
declare cphoto_tmp="${photo_tmp}/${ptf}"

mkdir -p "${cphoto_tmp}"

while [[ true ]]
do
  
  cp=$(head -n ${iter} "${fileslisttxt}" | tail -n 1)
  cp_rel=${cp:${#photo_root}:${#cp}}
  cp_rel_dir=$(dirname "${cp_rel}")
  
  cpsize=$(du -b "${cp}")
  cpsize=${cpsize%%[[:space:]]*}
  
  iso_csize=${iso_csize}+${cpsize}
  
  iter=${iter}+1
  fter=${fter}+1
  
  newdir=${cphoto_tmp}"/"${cp_rel_dir}
  cp_newloc=${newdir}"/"$(basename "${cp}")
  
  if [[ ! -d "${newdir}" ]]
  then
    mkdir -p "${newdir}"
  fi
  
  if [[ $? -ne 0 ]]
  then
    echo "ERROR WHILE CREATE DIR: '${newdir}'"
    continue 
  fi
  
  cp "${cp}" "${newdir}"
  
  if [[ $? -ne 0 ]]
  then
    echo "ERROR WHILE COPY FILE: '${cp}'"
    continue 
  fi
  
  if [[ ${iso_csize} -ge ${iso_size} || ${iter} -gt ${photo_count} ]]
  then
  
    if [[ ${iso_csize} -gt ${iso_size} ]]
    then
      #removing last file to decrease iso size
      rm -f "${cp_newloc}"
      iso_csize=${iso_csize}-${cpsize}
      iter=$iter-1
      fter=${fter}-1
    fi
  
    iso_cname="${iso_root}/DVD_"$(date "+%d.%m.%Y_%H:%M:%S")"-${jter}.iso"
    
    echo "generating ISO current name: $iso_cname"
    echo "files: "${fter}
    echo "current iso size: "${iso_csize}

    genisoimage -q -allow-leading-dots -allow-lowercase \
                -allow-multidot -D -iso-level 4 -o "${iso_cname}" "${cphoto_tmp}"
    
    rm -fr "${cphoto_tmp}"
    
    if [[ ${iter} -gt ${photo_count} ]]
    then
      break ;
    fi
    
    jter=${jter}+1
    iso_csize=0
    fter=0
    
    ptf=${ptf}+1
    cphoto_tmp="${photo_tmp}/${ptf}"
    
    mkdir -p "${cphoto_tmp}"
  fi
  
done

echo "DONE!"
