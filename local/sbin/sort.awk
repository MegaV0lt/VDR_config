BEGIN {
  FS=":";
  a=0;
}

function sortout(b, n, c) {
  o["C"] = "DVB-C";
  o["T"] = "DVB-T";
  o["S9.0E"] = "Eurobird 9° Ost";
  o["S19.2E"] = "Astra 19,2° Ost";
  o["S13.0E"] = "Hotbitd 13° Ost";


  # keys von b sortieren:
  n=asorti(b,copy)
  c=""
  for(i=1; i<n; i++) {
    m=split(copy[i],d,/;/)
    if (c!=d[1] ";" d[2]) {
      c=d[1] ";" d[2];

      # ohne Satellit
      #print ":" d[1];

      # mit Satellit
      split(b[copy[i]],e,/:/);
      if (o[e[4]] != "") {
        print ":" d[1] " - " o[e[4]];
      } else {
        print ":" d[1] " - " e[4];
      }
    }
    print  b[copy[i]];
  }
}

{
  if ($1 =="") {
    if ($2 == "Andere") {
       a=1;
       print $0;
    } else if (a==0) {
      print $0;
    }
  } else {
    if (a==1) {
      n=split($1,s,/;/);
      if (n==1) {
        b["No Provider;" $4 ";" s[1]] = $0;
      } else {
        b[s[2] ";" $4 ";" s[1]] = $0;
      }
    } else {
      print $0;
    }
  }
}

END {
  sortout(b);
}

