use strict;
use warnings;

open(IN,$ARGV[0]);
open(GFF,$ARGV[1]);
open(OUT,">$ARGV[2]");

my @asd;
my %hash;

while(<IN>){
    chomp;
    my @arr = split(/\t/);
    my $key = $arr[0]."\t".$arr[2]."\t".$arr[3]."\t".$arr[4];
    $hash{$key} = $arr[8];
}

while(<GFF>){
    chomp;
    my @arr = split(/\t/);
    my $key = $arr[0]."\t".$arr[2]."\t".$arr[3]."\t".$arr[4];
    if(exists $hash{$key}){$arr[8] = $hash{$key};
    print OUT join("\t",@arr)."\n";}
}
