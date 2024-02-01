#!/usr/bin/perl
$Virt = "U";
$Res = "U";
sub MB
{
  my $s = shift;
  if    ($s =~ s/g$//) { $s *= 1000; }
  elsif ($s =~ s/m$//) { }
  else                 { $s /= 1000; }
  return $s;
}
if ($ARGV[0]) {
   $s = `/usr/bin/top -b -n 1 | grep -w $ARGV[0] | head -1`;
   chomp($s);
   if ($s) {
      $s =~ s/^ *//;
      @a = split(/ +/, $s);
      $Virt = MB($a[4]);
      $Res  = MB($a[5]);
      }
   }
print "$Virt\n$Res\n";

