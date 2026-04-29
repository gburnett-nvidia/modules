process PARABRICKS_GIRAFFE {
    tag "${meta.id}"
    label 'process_high'
    label 'process_gpu'
    // needed by the module to work properly — see: https://github.com/nf-core/modules/issues/7226
    stageInMode 'copy'

    container "nvcr.io/nvidia/clara/clara-parabricks:4.6.0-1"

    input:
    tuple val(meta),  path(reads)
    tuple val(meta2), path(fasta), path(fai)
    path gbz_file
    path dist_file
    path minimizer_file
    path hapl_file
    path ri_file

    output:
    tuple val(meta), path("${prefix}.bam"), emit: bam
    tuple val(meta), path("${prefix}.bam.bai"), emit: bai, optional: true
    tuple val("${task.process}"), val('parabricks'), eval("pbrun version | grep -m1 '^pbrun:' | sed 's/^pbrun:[[:space:]]*//'"), topic: versions, emit: versions_parabricks

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Parabricks module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }
    def args   = task.ext.args ?: ''
    prefix     = task.ext.prefix ?: "${meta.id}"

    def reads_list     = reads instanceof List ? reads : [reads]
    def in_reads_1     = reads_list[0]
    def in_reads_2     = reads_list.size() > 1 ? reads_list[1] : null
    def in_reads_cmd   = meta.single_end || !in_reads_2 ?
        "--in-reads-1 ${in_reads_1}" :
        "--in-reads-1 ${in_reads_1} --in-reads-2 ${in_reads_2}"

    def hapl_cmd       = hapl_file ? "--hapl-file ${hapl_file}" : ''
    def ri_cmd         = ri_file   ? "--r-index-file ${ri_file}" : ''
    def num_gpus       = task.accelerator ? "--num-gpus ${task.accelerator.request}" : ''
    """
    pbrun \\
        giraffe \\
        --ref ${fasta} \\
        ${in_reads_cmd} \\
        --gbz-file ${gbz_file} \\
        --dist-file ${dist_file} \\
        --minimizer-file ${minimizer_file} \\
        --out-bam ${prefix}.bam \\
        ${hapl_cmd} \\
        ${ri_cmd} \\
        ${num_gpus} \\
        ${args}
    """

    stub:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Parabricks module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }
    def args = task.ext.args ?: ''
    prefix   = task.ext.prefix ?: "${meta.id}"
    """
    echo "${args}"
    touch ${prefix}.bam
    touch ${prefix}.bam.bai
    """
}
