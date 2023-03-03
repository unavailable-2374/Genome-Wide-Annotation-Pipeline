# Zhou Lab @ AGIS Genome-Wide-Annotation-Pipeline
This is a workflow that combines multiple software, mainly for whole genome annotation of eukaryotes.

<img width="600" alt="The GWAP workflow" src="https://github.com/unavailable-2374/Genome-Wide-annotation-pipeline/blob/main/img/注释.pdf?raw=true" >

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

### 1.Download the latest Pipeline:

    git clone https://github.com/unavailable-2374/Genome-Wide-annotation-pipeline.git
    
### 2.Install
    
#### If you do not have much experience in compiling software, it is recommended to use conda to complete most of the software installation.
   
    cd Genome-Wide-annotation-pipeline
    mamba env create -f anno_tools.yml
    conda activate anno_tools
    
#### Manual installation section. 
 
 Download and cat PFAM_dabase
    
    wget ftp://ftp.ebi.ac.uk/pub/databases/Pfam/releases/Pfam27.0/Pfam-A.hmm.gz 
    wget ftp://ftp.ebi.ac.uk/pub/databases/Pfam/releases/Pfam27.0/Pfam-B.hmm.gz 
    gzip -dc Pfam-A.hmm.gz > Pfam-AB.hmm
    gzip -dc Pfam-B.hmm.gz >> Pfam-AB.hmm
    
## Usage

        Usage:
            perl run_annotate.pl [options]
        For example:
            perl run_annotate.pl --genome genome.fasta -1 rna_1.1.fq.gz,rna_2.1.fq.gz -2 rna_1.2.fq.gz,rna_2.2.fq.gz --protein homolog.fasta --out_prefix out --cpu 80 --gene_prefix Vitis --Pfam_db /PATH-to/Pfam-AB.hmm
        Parameters:
        [General]
            --genome <string>     Required
            genome file in fasta format.
            -1 <string> -2 <string>    Required
            fastq format files contain of paired-end RNA-seq data. if you have data come from multi librarys, input multi fastq files separated by comma. the compress file format .gz also can be accepted.
            --protein <string>    Required
            homologous protein sequences (derived from multiple species would be recommended) file in fasta format.
            --augustus_species <string>    Required when --use_existed_augustus_species were not provided
            species identifier for Augustus. the relative hmm files of augustus training will be created with this prefix. if the relative hmm files of augustus training exists, the program will delete the hmm files directory firstly, and then start the augustus training steps.
           [other]
            --out_prefix <string>    default: out
            the prefix of outputs.
            --use_existed_augustus_species <string>    Required when --augustus_species were not provided
            species identifier for Augustus. This parameter is conflict with --augustus_species. When this parameter set, the --augustus_species parameter will be invalid, and the relative hmm files of augustus training should exists, and the augustus training step will be skipped (this will save lots of runing time).
            --RM_species <string>    default: None
            species identifier for RepeatMasker. The acceptable value of this parameter can be found in file $dirname/RepeatMasker_species.txt. Such as, Eukaryota for eucaryon, Fungi for fungi, Viridiplantae for plants, Metazoa for animals. The repeats in genome sequences would be searched aganist the Repbase database when this parameter set. 
            --RM_lib <string>    default: None
            A fasta file of repeat sequences. Generally to be the result of RepeatModeler. If not set, RepeatModeler will be used to product this file automaticly, which shall time-consuming.
            --augustus_species_start_from <string>    default: None
            species identifier for Augustus. The optimization step of Augustus training will start from the parameter file of this species, so it may save much time when setting a close species.
            --cpu <int>    default: 4
            the number of threads.
            --strand_specific    default: False
            enable the ability of analysing the strand-specific information provided by the tag "XS" from SAM format alignments. If this parameter was set, the paramter "--rna-strandness" of hisat2 should be set to "RF" usually.
            --Pfam_db <string>    default: None
            the absolute path of protein family HMM database which was used for filtering of false positive gene models. multiple databases can be input, and the prefix of database files should be seperated by comma.
            --gene_prefix <string>    default: gene
            the prefix of gene id shown in output file.
            --step [all|maker_only|geta_only] Specify which steps you want to run the pipe.
            all:run the entire pipeline (default)
            maker_only:run maker 2 times
            geta_only:use GETA Pipeline to anntate the genome
            --polish [on/off] default:on
            use PASA to polish 
            --help|-h Display this help info
            
            Version: 1.0
