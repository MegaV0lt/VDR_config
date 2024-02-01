#!/bin/env bash


VIDEO="${1:-/video}"  # Video-Verzeichniss

cd "$VIDEO" || exit 1

#Ordner mit # im Namen
mapfile -d $'\0' dirs < <(find -maxdepth 2 -type d -name "*#*" -print0)
dirnum="${#dirs[@]}"
[[ "$dirnum" -eq 0 ]] && { echo "Keine Ordner mit \# im Namen gefunden" ; exit ;}

while [[ "$dirnum" -ge 0 ]] ; do
  [[ "${dirs[dirnum]}" == '' ]] && { ((dirnum--)) ; continue ;}

  # Sonderzeichen übersetzen
  unset -v 'OUT'
  dirname="${dirs[dirnum]}"
  while [[ "${dirname//#/}" != "$dirname" ]] ; do
    tmp="${dirname#*#}" ; char="${tmp:0:2}" ; ch="$(echo -e "\x$char")"
    OUT="${OUT}${dirname%%#*}${ch}" ; dirname="${tmp:2}"
  done

  # Umbenennen
  echo "Benenne \"${dirs[dirnum]}\" nach \"${OUT}${dirname}\" um…"
  mv "${dirs[dirnum]}" "${OUT}${dirname}"
  ((dirnum--))
done

echo "Fertig"
exit
