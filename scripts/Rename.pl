use strict;
use warnings;

open(IN,$ARGV[0]);
open(OUT,">$ARGV[1]");

my $new_id;
my @asd;
my $sort = 1;
my $chr_name = "s";

while(<IN>){
    chomp;
    my @arr = split(/\t/);
    if($arr[2] eq "gene"){
        if($chr_name ne $arr[0]){$sort = 1;}
        @asd = split(/\;/,$arr[8]);
        $asd[0] =~ s/ID=//g;
        my $chr = $arr[0];
        #$chr =~ s/BMNG_hap1_chr//g;
        #$chr=(sprintf "%02d", $chr);
        $sort = (sprintf "%05d", $sort);
        $new_id = "Vitvi".$chr."g".$sort;
        $_ =~ s/$asd[0]/$new_id/g;
        print OUT $_."\n";
        $sort++;
        $chr_name = $arr[0];
    }else{
        $_ =~ s/$asd[0]/$new_id/g;
        print OUT $_."\n";
    }
}
