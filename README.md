# Zhou Lab @ AG IS Genome-Wide-annotation-pipeline
This is a workflow that combines multiple software, mainly for whole genome annotation of eukaryotes.

## Requirements

### Tools

The following tools are required. Some options and compatibilities might depend on the software version. We successfully ran the pipeline using the versions described below.

- [augustus v.3.0.3](http://bioinf.uni-greifswald.de/augustus/)
- [bedtools v.2.26.0](https://bedtools.readthedocs.io/en/latest/) 
- [BLAST v.2.6.0+](https://blast.ncbi.nlm.nih.gov/Blast.cgi?PAGE_TYPE=BlastDocs&DOC_TYPE=Download)
- [Blast2GO v.4.1.9](https://www.blast2go.com/)
- [BLAT v.36x2](https://genome.ucsc.edu/FAQ/FAQblat.html)
- [busco v.3.0.2](https://busco.ezlab.org/)
- [EVidenceModeler v.1.1.1](https://evidencemodeler.github.io/)
- [exonerate v.2.2.0](https://www.ebi.ac.uk/about/vertebrate-genomics/software/exonerate-manual)
- [fastqc v.0.10.1](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/)
- [genemark v.3.47](http://exon.gatech.edu/GeneMark/)
- [gffcompare v.0.10.1](https://ccb.jhu.edu/software/stringtie/gffcompare.shtml)
- [gffread](http://ccb.jhu.edu/software/stringtie/gff.shtml)
- [gmap v.2015-09-29](http://research-pub.gene.com/gmap/)
- [hisat2 v.2.0.5](https://ccb.jhu.edu/software/hisat2/manual.shtml)
- [interproscan v.5.28-67.0](https://www.ebi.ac.uk/interpro/search/sequence/)
- [IsoSeq v.3](https://github.com/PacificBiosciences/IsoSeq)
- [LSC v.2.0](http://augroup.org/LSC/LSC)
- [magicblast v.1.4.0](https://ncbi.github.io/magicblast/)
- [maker v.2.31.9](https://www.yandell-lab.org/software/maker.html)
- [parallel](https://www.gnu.org/software/parallel/)
- [PASA v.2.3.3](https://github.com/PASApipeline/PASApipeline/wiki)
- [RepeatMasker v.open-4.0.6](http://www.repeatmasker.org/)
- [samtools v.1.7](http://www.htslib.org/)
- [SNAP v.2006-07-28](https://github.com/KorfLab/SNAP)
- [stringtie v.1.3.4d](https://ccb.jhu.edu/software/stringtie/)
- [TransDecoder v.3.0.1](https://github.com/TransDecoder/TransDecoder/wiki)
- [trimmomatic v.0.36](http://www.usadellab.org/cms/?page=trimmomatic)
- [Trinity v.2.6.5](https://github.com/trinityrnaseq/trinityrnaseq/wiki)

### Folder structure

Most of the tools are assumed to be installed in the `PATH`. If not, the absolute `PATH` to the `Tools` directory is given.

```bash
2-Annotation
├── 2_0-External_evidences
│   ├── 2_0_1-Proteins
│   └── 2_0_2-mRNAs
│       ├── 2_0_2_1-External_databases
│       ├── 2_0_2_2-RNAseq
│       │   ├── 2_0_2_2_1-RNAseq_reads
│       │   └── 2_0_2_2_2-RNAseq_assembly
│       └── 2_0_2_3-IsoSeq
│           ├── 2_0_2_3_1-IsoSeq_reads
│           └── 2_0_2_3_2-IsoSeq_polishing
├── 2_1-Training
│   ├── 2_1_1-Training_set
│   │   └── pasa_run.log.dir
│   └── 2_1_2-Predictor_training
│       ├── 2_1_2_1-Augustus
│       ├── 2_1_2_2-Genemark
│       └── 2_1_2_3-SNAP
└── 2_2-Prediction
    ├── 2_2_1-Repeats
    ├── 2_2_2-
    ├── 2_2_3-Prediction
    │   ├── 2_2_3_1-BUSCO
    │   ├── 2_2_3_2-Augustus
    │   ├── 2_2_3_3-Genemark
    │   ├── 2_2_3_4-SNAP
    │   └── 2_2_3_5-PASA
    ├── 2_2_4-Transcript_mapping
    ├── 2_2_5-Protein_mapping
    ├── 2_2_6-EVM
    ├── 2_2_7-Annotation_polishing
    ├── 2_2_8-Filtering
    └── 2_2_9-Functional_annotation
```

## Pipeline

- [0 - External evidences](Pipeline/0_External_evidences.md)
- [1 - Repeat annotation](Pipeline/1_Repeat_annotation.md)
- [2 - Training set creation](Pipeline/2_Training_set_creation.md)
- [3 - Ab initio predictors training](Pipeline/3_Ab_initio_predictors_training.md)
- [4 - Ab initio prediction](Pipeline/4_Ab_initio_prediction.md)
- [5 - Evidence alignment](Pipeline/5_Evidence_alignment.md)
- [6 - Gene models consensus call (EVM)](Pipeline/6_Gene_models_consensus_call_(EVM).md)
- [7 - Filtering](Pipeline/7_Filtering.md)
- [8 - Renaming](Pipeline/8_Renaming.md)
- [9 - Functional annotation](Pipeline/9_Functional_annotation.md)

## References

- **Andrews S** (2014) FastQC: A Quality Control tool for High Throughput Sequence Data. 
- **Au KF, Underwood JG, Lee L, Wong WH** (2012) Improving PacBio Long Read Accuracy by Short Read Alignment. PLoS ONE **7**: e46679
- **Bolger AM, Lohse M, Usadel B** (2014) Trimmomatic: a flexible trimmer for Illumina sequence data. Bioinformatics **30**: 2114–2120
- **Boratyn GM, Thierry-Mieg J, Thierry-Mieg D, Busby B, Madden TL** (2019) Magic-BLAST, an accurate RNA-seq aligner for long and short reads. BMC Bioinformatics **20**: 405
- **Camacho C, Coulouris G, Avagyan V, Ma N, Papadopoulos J, Bealer K, Madden TL** (2009) BLAST+: architecture and applications. BMC Bioinformatics. doi: 10.1186/1471-2105-10-421
- **Cantarel BL, Korf I, Robb SMC, Parra G, Ross E, Moore B, Holt C, Sanchez Alvarado A, Yandell M** (2007) MAKER: An easy-to-use annotation pipeline designed for emerging model organism genomes. Genome Research **18**: 188–196
- **Gotz S, Garcia-Gomez JM, Terol J, Williams TD, Nagaraj SH, Nueda MJ, Robles M, Talon M, Dopazo J, Conesa A** (2008) High-throughput functional annotation and data mining with the Blast2GO suite. Nucleic Acids Research **36**: 3420–3435
- **Haas BJ** (2003) Improving the Arabidopsis genome annotation using maximal transcript alignment assemblies. Nucleic Acids Research **31**: 5654–5666
- **Haas BJ, Papanicolaou A, Yassour M, Grabherr M, Blood PD, Bowden J, Couger MB, Eccles D, Li B, Lieber M, Macmanes MD, Ott M, Orvis J, Pochet N, Strozzi F, Weeks N, Westerman R, William T, Dewey CN, Henschel R, Leduc RD, Friedman N, Regev A** (2013) De novo transcript sequence reconstruction from RNA-seq using the Trinity platform for reference generation and analysis. Nature Protocols **8**: 1494–512
- **Haas BJ, Salzberg SL, Zhu W, Pertea M, Allen JE, Orvis J, White O, Buell CR, Wortman JR** (2008) Automated eukaryotic gene structure annotation using EVidenceModeler and the Program to Assemble Spliced Alignments. Genome Biol **9**: R7
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
- **Tange O** (2011) GNU Parallel: The Command-Line Power Tool. ;login: The USENIX Magazine **36**: 42–47
- **W. James Kent** (2002) BLAT : The Blast-Like Alignment Tool. Genome Res **12**: 656–664
- **Wu TD, Watanabe CK** (2005) GMAP: a genomic mapping and alignment program for mRNA and EST sequences. Bioinformatics **21**: 1859–1875
