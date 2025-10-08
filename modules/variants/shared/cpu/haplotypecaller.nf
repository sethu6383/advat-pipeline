process HAPLOTYPECALLER_CHR {
    tag "$sample_id - $chromosome"
    label 'medium_cpu'
    
    input:
    tuple val(sample_id), path(bam), path(bai), val(chromosome)
    path reference
    path reference_index
    path reference_dict
    path intervals
    
    output:
    tuple val(sample_id), path("${sample_id}.${chromosome}.vcf.gz"), path("${sample_id}.${chromosome}.vcf.gz.tbi"), emit: vcf
    
    script:
    def interval_arg = intervals ? "-L ${intervals}/${chromosome}.interval_list" : "-L ${chromosome}"
    def emit_conf = params.emit_ref_confidence != 'NONE' ? "-ERC ${params.emit_ref_confidence}" : ""
    """
    gatk HaplotypeCaller \\
        -R ${reference} \\
        -I ${bam} \\
        ${interval_arg} \\
        -O ${sample_id}.${chromosome}.vcf.gz \\
        --native-pair-hmm-threads ${task.cpus} \\
        --stand-call-conf ${params.call_conf} \\
        ${emit_conf} \\
        --java-options "-Xmx${task.memory.toGiga()}g -XX:+UseParallelGC -XX:ParallelGCThreads=${task.cpus}"
    """
}