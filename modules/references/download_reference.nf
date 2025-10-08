process DOWNLOAD_REFERENCE {
    label 'low_cpu'
    storeDir "${params.reference_dir}/${genome_version}"
    
    input:
    val genome_version  // hg38 or hg19
    
    output:
    path "${genome_version}.fa", emit: fasta
    path "${genome_version}.fa.fai", emit: fai
    path "${genome_version}.dict", emit: dict
    
    script:
    if (genome_version == 'hg38') {
        """
        # Download hg38 reference from NCBI
        wget -O ${genome_version}.fa.gz \\
            https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/000/001/405/GCA_000001405.15_GRCh38/seqs_for_alignment_pipelines.ucsc_ids/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.gz
        
        gunzip ${genome_version}.fa.gz
        
        # Create index
        samtools faidx ${genome_version}.fa
        
        # Create dictionary
        gatk CreateSequenceDictionary \\
            -R ${genome_version}.fa \\
            -O ${genome_version}.dict
        """
    } else if (genome_version == 'hg19') {
        """
        # Download hg19 reference from UCSC
        wget -O ${genome_version}.fa.gz \\
            https://hgdownload.cse.ucsc.edu/goldenPath/hg19/bigZips/hg19.fa.gz
        
        gunzip ${genome_version}.fa.gz
        
        # Create index
        samtools faidx ${genome_version}.fa
        
        # Create dictionary
        gatk CreateSequenceDictionary \\
            -R ${genome_version}.fa \\
            -O ${genome_version}.dict
        """
    } else {
        error "Unsupported genome version: ${genome_version}"
    }
}