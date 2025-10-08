process EXPANSION_HUNTER {
    tag "$sample_id"
    label 'medium_cpu'
    
    publishDir "${params.outdir}/variants/repeats", mode: params.publish_dir_mode
    
    input:
    tuple val(sample_id), path(bam), path(bai)
    path reference
    path variant_catalog
    
    output:
    tuple val(sample_id), path("${sample_id}_expansionhunter.vcf"), emit: vcf
    path "${sample_id}_expansionhunter.json", emit: json
    
    when:
    params.run_expansion_hunter && !params.skip_expansion_hunter
    
    script:
    """
    ExpansionHunter \\
        --reads ${bam} \\
        --reference ${reference} \\
        --variant-catalog ${variant_catalog} \\
        --output-prefix ${sample_id}_expansionhunter \\
        --threads ${task.cpus} \\
        --sex auto-detect
    """
}