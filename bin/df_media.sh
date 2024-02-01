#!/usr/bin/env bash
# df_media.sh
#
# Gibt die Belegung der der eingehängten Medien in /media und optional den
# belegten Platz auf /video aus.
#
#VERSION=230412

# Variablen
VIDEO_DIR='/video'      # Interner Plattenplatz (Auskommentieren wenn nicht gewünscht)
MEDIA_DIR='/media/vdr'  # Plattenplatz auf externen Medien

# Start
if [[ -n "$VIDEO_DIR" ]] ; then
   mapfile -t < <(df -Ph "$VIDEO_DIR")       # Ausgabe von df in Array (Zwei Zeilen)
   echo "==> Interner Speicher (${VIDEO_DIR})"
   echo -e "${MAPFILE[0]}\n${MAPFILE[1]}\n"  # Ausgabe (2 Zeilen)
fi

for dir in "$MEDIA_DIR"/* ; do
   [[ ! -d "$dir" ]] && continue
   mapfile -t < <(df -Ph "$dir")  # Ausgabe von df in Array (Zwei Zeilen)
   DF_LINE=(${MAPFILE[1]}) ; DF_DEV="${DF_LINE[0]}"  # Erstes Element ist das Device
   if [[ ! "${DF_DEVS[@]}" =~ "$DF_DEV" ]] ; then # Jedes Device nur ein mal
      DF_DEVS+=("$DF_DEV")                    # Device der Liste hinzu fügen
      if [[ -z "$cnt" ]] ; then               # 1. Zeile ausgeben (Nur ein mal)
         echo "==> Externe(r) Speicher (${MEDIA_DIR})"
         echo "${MAPFILE[0]}" && cnt=1
      fi
      echo "${MAPFILE[1]}"                    # 2. Zeile mit den Daten ausgeben
      #echo -e "${MAPFILE[0]}\n${MAPFILE[1]}\n"  # Alternative Ausgabe (immer 2 Zeilen)
   fi
done
