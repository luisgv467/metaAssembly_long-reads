#Snakemake workflow for cleaning raw metagenomes 

import os

#Preparing files 

configfile: "config/config.yml"

INPUT = config["input"]
INPUT_PATH = config["input_path"]
ASSEMBLY = config["assembly"]
CONTIGS = config["contigs"]
ALIGNMENT = config["alignment"]
POLISHED = config["polished"]

with open(INPUT) as f:
    SAMPLES = [line.strip() for line in f if line.strip()]

###### Protocol ######

rule all:
	input:
		expand("{sample}-all_done.txt", sample=SAMPLES)

rule metaflye:
	input:
		INPUT_PATH + "{sample}.fastq.gz"
	output:
		assembly = directory(ASSEMBLY + "{sample}-ONT"),
		flag = "{sample}-flye_done.txt"
	conda:
		"envs/metassembly_long-reads.yml"
	shell:
		"""
		flye --nano-hq {input} -t 24 --meta -o {output.assembly}
		touch {output.flag}
		"""

rule contigs:
	input:
		"{sample}-flye_done.txt"
	params:
		file = ASSEMBLY + "{sample}-ONT/assembly.fasta",
		assembly = directory(ASSEMBLY + "{sample}-ONT")
	output:
		contigs = CONTIGS + "{sample}-ONT.fa",
		flag = "{sample}-contig_done.txt"
	conda:
		"envs/metassembly_long-reads.yml"
	shell:
		"""
		mv {params.file} {output.contigs}
		rm -r {params.assembly}
		touch {output.flag}
		"""
    
rule align:
	input:
		"{sample}-contig_done.txt"
	params:
		contigs = CONTIGS + "{sample}-ONT.fa",
		clean_fastq = INPUT_PATH + "{sample}.fastq.gz"
	output:
		alignment = ALIGNMENT + "{sample}_alignments.paf",
		flag = "{sample}-alignment_done.txt"
	conda:
		"envs/metassembly_long-reads.yml"
	shell:
		"""
		minimap2 \
		-t 24 \
		-x map-ont \
		{params.contigs} \
		{params.clean_fastq} > {output.alignment} 
		touch {output.flag}
		"""
        
rule polish:
	input:
		"{sample}-alignment_done.txt"
	params:
		clean_fastq = INPUT_PATH + "{sample}.fastq.gz",
		alignment = ALIGNMENT + "{sample}_alignments.paf",
		contigs = CONTIGS + "{sample}-ONT.fa"
	output:
		polished = POLISHED + "{sample}-ONT-polished.fasta",
		flag = "{sample}-all_done.txt"
	conda:
		"envs/metassembly_long-reads.yml"
	shell:
		"""
		racon \
		-t 32  \
		{params.clean_fastq} \
		{params.alignment} \
		{params.contigs} > {output.polished} 
		touch {output.flag}
		"""
        
