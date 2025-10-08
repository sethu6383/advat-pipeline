process BWA_MEM2_ALIGN {
    tag "$sample_id"
    label 'very_high_cpu'
    
    publishDir "${params.outdir}/alignment/raw_bam", mode: params.publish_dir_mode, enabled: params.save_intermediate
    
    input:
    tuple val(sample_id), path(read1), path(read2)
    path bwa_index
    path reference
    
    output:
    tuple val(sample_id), path("${sample_id}_raw.bam"), emit: bam
    
    script:
    def rg_line = "@RG\\tID:${sample_id}\\tSM:${sample_id}\\tPL:ILLUMINA\\tLB:${sample_id}_lib"
    """
    bwa-mem2 mem \\
        -t ${task.cpus} \\
        -R "${rg_line}" \\
        -K 100000000 \\
        -Y \\
        ${reference} \\
        ${read1} ${read2} | \\
    samtools view \\
        -@ ${task.cpus} \\
        -b \\
        -o ${sample_id}_raw.bam \\
        -
    """
}