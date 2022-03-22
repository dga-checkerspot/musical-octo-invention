#!/usr/bin/env nextflow

sequences1='s3://transcriptome.seeds.illumina.rawdata/IlluminaAcceleratorMiSeqRuns_S/TranscriptomeSeeds-60142091/72118476/ds.29cbff3a430b443cbf4b0a9a5380e5e7/LobtusilobaRNA_S1_L001_R1_001.fastq.gz'
sequences12='s3://transcriptome.seeds.illumina.rawdata/IlluminaAcceleratorMiSeqRuns_S/TranscriptomeSeeds-60142091/72118476/ds.29cbff3a430b443cbf4b0a9a5380e5e7/LobtusilobaRNA_S1_L001_R2_001.fastq.gz'
pairInt='s3://transcriptomepipeline/PairInterleaves.sh'


sequencedataset1= Channel.fromPath(sequences1)
sequencedataset2= Channel.fromPath(sequences12)

process cutadapt11 {
	memory '16G'
	
	input:
	path 'cleanfas' from sequencedataset1
	
	output:
	file 'R1.fastq' into reads11
	
	"""
	cutadapt --rename='{id}/1' $cleanfas -j 0 -o R1.fastq
	"""
}

process cutadapt12 {
	memory '16G'
	
	input:
	path 'cleanfas' from sequencedataset2
	
	output:
	file 'R2.fastq' into reads12
	
	"""
	cutadapt --rename='{id}/2' $cleanfas -j 0 -o R2.fastq
	"""
}

process bbnorm {

	memory '196G'
	
        input:
        path seq1 from reads11
        path seq2 from reads12
        
        output:
        file 'mid.fq' into ReadTrimNorm1

	"""
	bbnorm.sh in=$seq1 in2=$seq2 outlow=low.fq outmid=mid.fq outhigh=high.fq passes=1 lowbindepth=6 highbindepth=150 -Xmx192g
	"""
}



process pairInt {

	memory '4G'

	input:
	path 'pairInt' from pairInt
	path 'Intpair' from ReadTrimNorm1

	output:
	file 'R1reads.fastq' into R1Tofastq
	file 'R2reads.fastq' into R2Tofastq

	"""
	chmod 744 $pairInt
	./$pairInt < $Intpair R1reads.fastq R2reads.fastq
	"""

}


process fastqpair2 {

	memory '32G'

	input:
	path R1p from R1Tofastq
	path R2p from R2Tofastq

	output:
	file 'R1reads.fastq.paired.fq' into pairR1T
	file 'R2reads.fastq.paired.fq' into pairR2T
	//For now not even bothering with unpaired

	"""
	fastq_pair -t 100000000 $R1p $R2p
	"""
}

pairR1T.into{P1NormSpades; P1NormTrinity}
pairR2T.into{P2NormSpades; P2NormTrinity}


process SpadeAssemble {
	
  memory '96G'

  input:
    path R1Norm from P1NormSpades
    path R2Norm from P2NormSpades

  output:
    file 'spades_output.tar.gz' into Spades
    
    """
    rnaspades.py  --pe1-1 $R1Norm --pe1-2 $R2Norm  -o spades_output
    tar -zcvf spades_output.tar.gz spades_output 
    
    """
    
    
}


process TrinityAssemble {
	
  memory '96G'
	
  input:
	path R1pair from P1NormTrinity
	path R2pair from P2NormTrinity
	
  output:
	file 'trinity_output.tar.gz' into Trinity
	
  """
	Trinity --seqType fq --left $R1pair --right $R2pair --max_memory 94G --output trinity_output
	tar -zcvf trinity_output.tar.gz trinity_output 
	"""

}



