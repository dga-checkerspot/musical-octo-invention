#!/usr/bin/env nextflow

//sequences1='s3://pipe.scratch.3/resources/ERR2041047.1_1.fastq'
//sequences12='s3://pipe.scratch.3/resources/ERR2041047.1_2.fastq'
pairInt='s3://transcriptomepipeline/PairInterleaves.sh'


//sequencedataset1= Channel.fromPath(sequences1)
//sequencedataset2= Channel.fromPath(sequences12)


sraLines1=file('s3://pipe.scratch.3/resources/accessions.txt')
    .readLines()
    .each { println it }


chlamyref='s3://pipe.scratch.3/resources/Chlamy23s.fasta'


process runfasta {
	
	input:
  	val accession from sraLines1
	
	output:
	tuple val(accession), file("${accession}_1.fastq"), file("${accession}_2.fastq") into dumpout
	
	
	"""
	fastq-dump --split-3 $accession
	"""

}

dumpout.into{dumpout1; dumpout2}




process cutadapt11 {
	memory '16G'
	
	input:
	tuple val(accession), file(R1), file(R2) from dumpout1
	
	output:
	tuple val(accession), file("${accession}_cut_1.fastq"), file("${accession}_cut_2.fastq") into readscut
	
	"""
	cutadapt --rename='{id}/1' $R1 -j 0 -o "${accession}_cut_1.fastq"
	cutadapt --rename='{id}/2' $R2 -j 0 -o "${accession}_cut_2.fastq"
	"""
}


process bbnorm {

	memory '196G'
	
        input:
	tuple val(accession), file(R1), file(R2) from readscut
        
        output:
	tuple val(accession), file("${accession}.mid.fq") into ReadTrimNorm1

	"""
	bbnorm.sh in=$R1 in2=$R2 outlow=low.fq outmid="${accession}.mid.fq" outhigh=high.fq passes=1 lowbindepth=6 highbindepth=150 -Xmx192g
	"""
}



process pairInt {

	memory '4G'

	input:
	path 'pairInt' from pairInt
	tuple val(accession), file(Intpair) from ReadTrimNorm1

	output:
	tuple val(accession), file("${accession}_norm_1.fastq"), file("${accession}_norm_2.fastq") into RTofastq

	"""
	chmod 744 $pairInt
	./$pairInt < $Intpair "${accession}_norm_1.fastq" "${accession}_norm_2.fastq"
	"""

}


process fastqpair2 {

	memory '32G'

	input:
	tuple val(accession), file(R1p), file(R2p) from RTofastq

	output:
	tuple val(accession), file("${R1p}.paired.fq"), file("${R2p}.paired.fq") into pairRT
	//For now not even bothering with unpaired

	"""
	fastq_pair -t 100000000 $R1p $R2p
	"""
}

pairRT.into{PNormSpades; PNormTrinity}



process SpadeAssemble {
	
  	memory '24G'

  	input:
  	tuple val(accession), file(R1p), file(R2p) from PNormSpades

  	output:
	file("${accession}.spades.tar.gz") into Spades
    
    	"""
    	rnaspades.py  --pe1-1 $R1p --pe1-2 $R2p  -o $accession
    	tar -zcvf "${accession}.spades.tar.gz" $accession
    
    	"""
    
    
}


process TrinityAssemble {
	
  	memory '196G'
	
  	input:
	tuple val(accession), file(R1p), file(R2p) from PNormTrinity
	
  	output:
	file("${accession}.trinity.tar.gz") into Trinity
	
  	"""
	Trinity --seqType fq --left $R1p --right $R2p --max_memory 190G --output "${accession}_trinity"
	tar -zcvf "${accession}.trinity.tar.gz" "${accession}_trinity"
	"""

}



