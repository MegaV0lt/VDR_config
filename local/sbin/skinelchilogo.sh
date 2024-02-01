#!/bin/sh

# skinelchilogo.sh
# Logos für Skinelchi verlinken

# In der Datei 'logoalias.txt', welche im gleichen Verzeichnis wie das Skript
#+liegt, werden die Link-Ziele der Logos festgelegt (Logo Link)
#+Beispiel: ard_de.jpg ARD.jpg
#
# Das Skript löscht bei jedem Durchgang vorher alle Symlinks im LOGODIR!

LOGODIR=/etc/vdr/plugins/skinelchi/hdlogos_jpg
LOGOSUBDIRS=(576 720 1080i)                   # Unterverzeichnisse mit Logos für
                                              #+(OSD-)Auflösungen 576, 720, 1080

if [ ! -d ${LOGODIR} ] ; then
   echo "${LOGODIR} nicht gefunden!"
   exit 1
fi

cd ${LOGODIR} || exit 1

# Alle Symlinks löschen
find . -maxdepth 2 -lname '*' -exec rm {} \;

cat $(dirname $0)/logoalias.txt | while read ; do
    LOGOALIAS=($REPLY)
    for SUBDIR in ${LOGOSUBDIRS[*]} ; do
        if [ "${LOGOALIAS[0]:0:1}" != "#" ] ; then
           if [ -e ${SUBDIR}/${LOGOALIAS[0]} -a ${#LOGOALIAS[*]} == 2 ] ; then
              #echo ${LOGOALIAS[*]}  # Ausgabe der Zeile
              if [ ${LOGOALIAS[0]} != ${LOGOALIAS[1]} ] ; then
                 echo "Verlinke ${LOGOALIAS[0]} nach ${LOGOALIAS[1]}"
                 ln -s ${LOGOALIAS[0]} ${SUBDIR}/${LOGOALIAS[1]}
              fi
           else
               echo "--> ${SUBDIR}/${LOGOALIAS[0]} nicht gefunden!"
           fi
        fi
    done
done

exit
