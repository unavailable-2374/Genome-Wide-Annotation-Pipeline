# Zhou Lab @ AG IS Genome-Wide-annotation-pipeline
This is a workflow that combines multiple software, mainly for whole genome annotation of eukaryotes.

## Requirements

### Tools

The following tools are required. Some options and compatibilities might depend on the software version. 

- [augustus v.3.4.0](http://bioinf.uni-greifswald.de/augustus/)
- [bedtools v.2.26.0](https://bedtools.readthedocs.io/en/latest/) 
- [BLAST v.2.6.0+](https://blast.ncbi.nlm.nih.gov/Blast.cgi?PAGE_TYPE=BlastDocs&DOC_TYPE=Download)
- [BLAT v.36x2](https://genome.ucsc.edu/FAQ/FAQblat.html)
- [busco v.5.4.3](https://busco.ezlab.org/)
- [cd-hit V4.8.1](https://github.com/weizhongli/cdhit/releases/download/)
- [exonerate v.2.4.0](https://www.ebi.ac.uk/about/vertebrate-genomics/software/exonerate-manual)
- [genewise v2.4.1](http://www.ebi.ac.uk/~birney/wise2/)
- [genometools V.1.6.2](http://genometools.org/pub/)
- [geta V.2.44](https://github.com/chenlianfu/geta)
- [gffread](http://ccb.jhu.edu/software/stringtie/gff.shtml)
- [hisat2 v.2.1.0](https://ccb.jhu.edu/software/hisat2/manual.shtml)
- [HMMER V.3.3.2](http://eddylab.org/software/hmmer/)
- [interproscan V.5.56-89.0](https://www.ebi.ac.uk/interpro/search/sequence/)
- [mafft V.7.508](https://mafft.cbrc.jp/alignment/software/)
- [magicblast V.1.4.0](https://ncbi.github.io/magicblast/)
- [maker v.3.01.03](https://www.yandell-lab.org/software/maker.html)
- [PASA v.2.5.2](https://github.com/PASApipeline/PASApipeline/wiki)
- [Pfam database](https://ftp.ebi.ac.uk/pub/databases/Pfam/releases/)
- [parafly r2013-01-21](https://sourceforge.net/projects/parafly/files/)
- [RepeatMasker v.4.1.2-p1](http://www.repeatmasker.org/)
- [RepeatModeler V.2.0.1](http://www.repeatmasker.org/RepeatModeler/)
- [samtools v.1.7](http://www.htslib.org/)
- [SNAP v.2006-07-28](https://github.com/KorfLab/SNAP)
- [stringtie v.2.2.1](https://ccb.jhu.edu/software/stringtie/)
- [TransDecoder v.5.5.0](https://github.com/TransDecoder/TransDecoder/wiki)
- [trimmomatic v.0.38](http://www.usadellab.org/cms/?page=trimmomatic)

## Software Installation 

1.Download the latest Pipeline:

    git clone https://github.com/unavailable-2374/Genome-Wide-annotation-pipeline.git
    
2.Install
    
If you do not have much experience in compiling software, it is recommended to use conda to complete most of the software installation.

    mamba env create -f anno_tools.yml
    conda activate anno_tools
    
 Manual installation section. 
 
  Download and cat PFAM_dabase
    
    wget ftp://ftp.ebi.ac.uk/pub/databases/Pfam/releases/Pfam27.0/Pfam-A.hmm.gz 
    wget ftp://ftp.ebi.ac.uk/pub/databases/Pfam/releases/Pfam27.0/Pfam-B.hmm.gz 
    gzip -dc Pfam-A.hmm.gz > Pfam-AB.hmm
    gzip -dc Pfam-B.hmm.gz >> Pfam-AB.hmm
    
  install geta
  
    git https://github.com/chenlianfu/geta.git
    echo 'PATH=/absolute_path/geta/bin ' >> ~/.bashrc


## References

- **Andrews S** (2014) FastQC: A Quality Control tool for High Throughput Sequence Data. 
- **Au KF, Underwood JG, Lee L, Wong WH** (2012) Improving PacBio Long Read Accuracy by Short Read Alignment. PLoS ONE **7**: e46679
- **Bolger AM, Lohse M, Usadel B** (2014) Trimmomatic: a flexible trimmer for Illumina sequence data. Bioinformatics **30**: 2114–2120
- **Boratyn GM, Thierry-Mieg J, Thierry-Mieg D, Busby B, Madden TL** (2019) Magic-BLAST, an accurate RNA-seq aligner for long and short reads. BMC Bioinformatics **20**: 405
- **Camacho C, Coulouris G, Avagyan V, Ma N, Papadopoulos J, Bealer K, Madden TL** (2009) BLAST+: architecture and applications. BMC Bioinformatics. doi: 10.1186/1471-2105-10-421
- **Cantarel BL, Korf I, Robb SMC, Parra G, Ross E, Moore B, Holt C, Sanchez Alvarado A, Yandell M** (2007) MAKER: An easy-to-use annotation pipeline designed for emerging model organism genomes. Genome Research **18**: 188–196
- **Haas BJ** (2003) Improving the Arabidopsis genome annotation using maximal transcript alignment assemblies. Nucleic Acids Research **31**: 5654–5666
- **Jones P, Binns D, Chang H-Y, Fraser M, Li W, McAnulla C, McWilliam H, Maslen J, Mitchell A, Nuka G, Pesseat S, Quinn AF, Sangrador-Vegas A, Scheremetjew M, Yong S-Y, Lopez R, Hunter S** (2014) InterProScan 5: genome-scale protein function classification. Bioinformatics **30**: 1236–1240
- **Kim D, Langmead B, Salzberg SL** (2015) HISAT: a fast spliced aligner with low memory requirements. Nat Methods **12**: 357–60
- **Korf I** (2004) Gene finding in novel genomes. BMC Bioinformatics. doi: 10.1186/1471-2105-5-59
- **Li H, Handsaker B, Wysoker A, Fennell T, Ruan J, Homer N, Marth G, Abecasis G, Durbin R, 1000 Genome Project Data Processing Subgroup** (2009) The Sequence Alignment/Map format and SAMtools. Bioinformatics **25**: 2078–2079
- **Lomsadze A** (2005) Gene identification in novel eukaryotic genomes by self-training algorithm. Nucleic Acids Research **33**: 6494–6506
- **Pertea M, Pertea GM, Antonescu CM, Chang T-C, Mendell JT, Salzberg SL** (2015) StringTie enables improved reconstruction of a transcriptome from RNA-seq reads. Nat Biotechnol **33**: 290–295
- **Quinlan AR, Hall IM** (2010) BEDTools: a flexible suite of utilities for comparing genomic features. Bioinformatics **26**: 841–842
- **Seppey M, Manni M, Zdobnov EM** (2019) BUSCO: Assessing Genome Assembly and Annotation Completeness. *In* M Kollmar, ed, Gene Prediction: Methods and Protocols. Springer New York, New York, NY, pp 227–245
- **Slater G, Birney E** (2005) Automated generation of heuristics for biological sequence comparison. BMC Bioinformatics. doi: 10.1186/1471-2105-6-31
- **Smit, AFA, Hubley, R, Green, P** (2013) RepeatMasker Open-4.0. 
- **Stanke M, Keller O, Gunduz I, Hayes A, Waack S, Morgenstern B** (2006) AUGUSTUS: ab initio prediction of alternative transcripts. Nucleic Acids Research **34**: W435–W439
- **W. James Kent** (2002) BLAT : The Blast-Like Alignment Tool. Genome Res **12**: 656–664
- **Wu TD, Watanabe CK** (2005) GMAP: a genomic mapping and alignment program for mRNA and EST sequences. Bioinformatics **21**: 1859–1875
