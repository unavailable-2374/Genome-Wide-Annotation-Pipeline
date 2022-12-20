use strict;
use warnings;

open(IN,$ARGV[0]);
my %ID;
my %POS;
my $sort = 1;
my $i = 1;
my $chr_name;

while(<IN>){
    chomp;
    my @arr = split(/\t/);
    if($arr[2] eq "gene"){
	$chr_name = $_;
        $ID{$chr_name} = "";
    }else{
        $ID{$chr_name } .= $_."\n";
    }
}

open(GFF,$ARGV[1]);
open(OUT,">".$ARGV[2]);

my $ids;

while(<GFF>){
    chomp;
    print OUT $_."\n".$ID{$_};
}
