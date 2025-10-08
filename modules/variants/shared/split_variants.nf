process SPLIT_VARIANTS {
    tag "$sample_id"
    label 'low_cpu'
    
    publishDir "${params.outdir}/variants/filtered", mode: params.publish_dir_mode
    
    input:
    tuple val(sample_id), path(vcf), path(tbi)
    path reference
    path reference_index
    path reference_dict
    
    output:
    tuple val(sample_id), path("${sample_id}_snps.vcf.gz"), path("${sample_id}_snps.vcf.gz.tbi"), emit: snps
    tuple val(sample_id), path("${sample_id}_indels.vcf.gz"), path("${sample_id}_indels.vcf.gz.tbi"), emit: indels
    
    script:
    """
    # Select SNPs
    gatk SelectVariants \\
        -R ${reference} \\
        -V ${vcf} \\
        -O ${sample_id}_snps.vcf.gz \\
        --select-type-to-include SNP \\
        --exclude-filtered \\
        --java-options "-Xmx${task.memory.toGiga()}g"
    
    tabix -p vcf ${sample_id}_snps.vcf.gz
    
    # Select INDELs
    gatk SelectVariants \\
        -R ${reference} \\
        -V ${vcf} \\
        -O ${sample_id}_indels.vcf.gz \\
        --select-type-to-include INDEL \\
        --exclude-filtered \\
        --java-options "-Xmx${task.memory.toGiga()}g"
    
    tabix -p vcf ${sample_id}_indels.vcf.gz
    """
}