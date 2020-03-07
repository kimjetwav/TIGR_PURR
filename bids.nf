usage = file("${workflow.scriptFile.getParent()}/usage/bids_usage")
bindings = [ "rewrite":"$params.rewrite",
             "subjects":"$params.subjects",
             "simg":"$params.simg",
             "descriptor":"$params.descriptor",
             "invocation":"$params.invocation",
             "license":"$params.license" ]
engine = new groovy.text.SimpleTemplateEngine()
toprint = engine.createTemplate(usage.text).make(bindings)
printhelp = params.help

if (!params.simg){

    log.info('Singularity container not specified!')
    log.info('Need --simg argument in Nextflow Call!')
    printhelp = true

}

if (!params.bids || !params.out) {

    log.info('Insufficient specification!')
    log.info('Need  --bids, --out!')
    printhelp = true

}

if (!params.application) {

    params.application="kimel_bidsapp"

}

if (!params.invocation || !params.descriptor) {

    log.info('Missing BOSH invocation and descriptor JSONs!')
    log.info('Exiting with Error')
    printhelp = true

}

if (!params.rewrite) {

    log.info("--rewrite flag not used, will skip existing outputs")

}else{

    log.info("--rewrite flag is on! Will re-run on existing outputs!")
    log.info("If you want to completely re-run, please delete subject output")

}

if (params.subjects) {

    log.info("Subject file provided: $params.subjects")

}

if (printhelp){
    print(toprint)
    System.exit(0)
}

log.info("BIDS Directory: $params.bids")
log.info("Output directory: $params.out")
log.info("Using Descriptor File: $params.descriptor")
log.info("Using Invocation File: $params.invocation")

// Main Processes

all_dirs = file(params.bids).list()
invalid_channel = Channel.create()
sub_channel = Channel.create()

// Store all subjects
input_dirs = new File(params.bids).list()
output_dirs = new File(params.out).list()

dataset_object_channel = Channel.create()

// Filter if rewrite
if (!params.rewrite){

    to_run = input_dirs.findAll { !(output_dirs.contains(it)) }

}else{

    to_run = input_dirs

}

bids_channel = Channel
                    .from(to_run)
                    .filter { it.contains('sub-') }

// Process subject list
if (params.subjects){


    //Load in sublist
    sublist = file(params.subjects)
    input_sub_channel = Channel.from(sublist)
                               .splitText() { it.strip() }

    process split_invalid{

        publishDir "$params.out/pipeline_logs/$params.application/", \
                 mode: 'copy', \
                 saveAs: { 'invalid_subjects.log' }, \
                 pattern: 'invalid'

        input:
        val subs from input_sub_channel.collect()
        val available_subs from bids_channel.collect()

        output:
        path 'valid' into valid_subs
        path 'invalid' optional true into invalid_subs


        """
        #!/usr/bin/env python

        import os
        print(os.getcwd())

        def nflist_2_pylist(x):
            x = x.strip('[').strip(']')
            x = [x.strip(' ').strip("\\n") for x in x.split(',')]
            return x

        #Process full BIDS subjects
        bids_subs = nflist_2_pylist("$available_subs")
        input_subs = nflist_2_pylist("$subs")

        print(input_subs)
        valid_subs = [x for x in input_subs if x in bids_subs]
        invalid_subs = [x for x in input_subs if x not in valid_subs]

        with open('valid', 'w') as f:
            f.writelines("\\n".join(valid_subs))

        if invalid_subs:

            with open('invalid', 'w') as f:
                f.writelines("\\n".join(invalid_subs))
                f.write("\\n")

        """

    }

    sub_channel = valid_subs
                        .splitText() { it.strip() }
}else{

    bids_channel.into(sub_channel)

}

process modify_invocation{

    input:
    val sub from sub_channel

    output:
    path "${sub}.json" into invoke_json

    """

    #!/usr/bin/env python

    import json

    out_file = '${sub}.json'
    invoke_file = '${params.invocation}'

    x = '${sub}'.replace('sub-', '')

    with open(invoke_file, 'r') as f:
        j_dict = json.load(f)

    j_dict.update({'participant_label': [x]})

    with open(out_file, 'w') as f:
        json.dump(j_dict, f, indent=4)

    """

}

process run_bids{

    input:
    path sub_input from invoke_json

    output:
    path '${PWD}/out/*' into dataset_object_channel

    beforeScript "source /etc/profile"
    stageInMode 'symlink'
    scratch true

    module 'slurm'
    shell:
    '''

    #Stop error rejection
    set +e

    #Set up working directory
    sub_json=!{sub_input}
    sub=${sub_json%.json}
    nf_workdir=${PWD}/out

    #Make logging output
    logging_dir=${nf_workdir}/pipeline_logs/!{params.application}
    log_out=${logging_dir}/${sub}.out
    log_err=${logging_dir}/${sub}.err
    mkdir -p ${logging_dir}

    echo !{sub_input}

    echo bosh exec launch \
    -v !{params.bids}:/bids \
    -v ${nf_workdir}:/output \
    -v !{params.license}:/license \
    !{params.descriptor} ${PWD}/!{sub_input} \
    --imagepath !{params.simg} -x --stream

    echo "TASK ATTEMPT !{task.attempt}" >> ${log_out}
    echo "============================" >> ${log_out}
    echo "TASK ATTEMPT !{task.attempt}" >> ${log_err}
    echo "============================" >> ${log_err}

    bosh exec launch \
    -v !{params.bids}:/bids \
    -v ${nf_workdir}:/output \
    -v !{params.license}:/license \
    !{params.descriptor} ${PWD}/!{sub_input} \
    --imagepath !{params.simg} -x --stream 1>> ${log_out} \
                                           2>> ${log_err}

    '''

}

process dataset_store{

    input:
    path '*' from dataset_object_channel.collect()
    path invocation from Channel.fromPath("$params.invocation")
    path commit_json from Channel.fromPath("$params.TODO_DUMMY_JSON")

    stageInMode 'symlink'

    shell:
    '''

    datestr="$(date -I)"
    invocation_object="$(basename -s '.json' !{params.invocation})_${datestr}"
    invocation_transobject="!{params.out}/${invocation}.json"
    report_transobject="!{params.out}/${invocation/_invocation/}.html"

    objects="`find out -type f -printf '%p ' | sed 's|out|!{params.out}/|g'`"
    canonical_dataset_objects="`readlink -e ${objects}`"
    dataset_transobjects="${objects} ${invoke_name}"
    finalised_dataset_transobjects="${dataset_transobjects} ${report_name}"

    echo '(datalad unlock "${canonical_dataset_objects}"
           install -g kimel_data -CD "${dataset_transobjects}" -t !{params.out}
           cd !{params.out}
           datalad save -S "${finalised_dataset_transobjects}")' \
               | at -M now+1minute

    '''

}
