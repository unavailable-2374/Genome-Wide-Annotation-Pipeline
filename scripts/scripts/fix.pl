use strict;
use warnings;

open(IN,$ARGV[0]);
open(OUT,">$ARGV[1]");

my @asd;
my @id;

while(<IN>){
    chomp;
    my @arr = split(/\t/);
    if($arr[8] =~ /maker/){
        if($arr[2] eq "gene"){
            @asd = split(/\;/,$arr[8]); 
            $asd[0] =~ s/ID=//g;
            $asd[1] =~ s/Name=//g;
            $arr[8] =~ s/$asd[1]/$asd[0]/g;
            print OUT join("\t",@arr)."\n";
        }elsif($arr[2] eq "mRNA"){
            my @array = split(/\;/,$arr[8]);
            @id = split(/\-mRNA-1;/,$arr[8]);
            $id[0] =~ s/ID=//g;
            $arr[8] =~ s/$id[0]/$asd[0]/g;
            $arr[8] =~ s/$asd[1]/$asd[0]/g;
            print OUT join("\t",@arr)."\n";
       }else{
            $arr[8] =~ s/$id[0]/$asd[0]/g;
            $arr[8] =~ s/$asd[1]/$asd[0]/g;
            print OUT join("\t",@arr)."\n";
       }
    }else{print OUT $_."\n";}
}
