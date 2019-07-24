// INPUT SPECIFICATION
// Don't use study, allow input to be specified freely

if (!params.simg){
    println('Singularity container not specified!')
    println('Need --simg argument in Nextflow Call!')
    System.exit(1)

}

if (!params.bids || !params.out) {

    println('Insufficient specification!')
    println('Need  --bids, --out!')
    System.exit(1)

}

println("BIDS Directory: $params.bids")
println("Output directory: $params.out")

//If params.application not specified, then use default bids_app
if (!params.application) {

    params.application="kimel_bidsapp"

}

// CHECK INVOCATION
if (!params.invocation || !params.descriptor) {

    println('Missing BOSH invocation and descriptor JSONs!')
    println('Exiting with Error')
    System.exit(1)


}else {

    println("Using Descriptor File: $params.descriptor")
    println("Using Invocation File: $params.invocation")

}

// Final Subjects check

if (params.subjects) {

    println("Subject file provided: $params.subjects")

}


//////////////////////////////////////////////////////////////

// Main Processes

all_dirs = file(params.bids)
invalid_channel = Channel.create()
sub_channel = Channel.create()

// Store all subjects
bids_channel = Channel
                    .from(all_dirs.list())
                    .filter { it.contains('sub-') }

// Process subject list
if (params.subjects){


    //Load in sublist
    sublist = file(params.subjects)
    input_sub_channel = Channel.from(sublist)
                               .splitText() { it.strip() }

    process split_invalid{

        publishDir "$params.out/pipeline_logs", \
                 mode: 'copy', \
                 saveAs: { 'invalid_subjects.log' }, \
                 pattern: 'invalid'

        input:
        val subs from input_sub_channel.collect()
        val available_subs from bids_channel.collect()

        output:
        file 'valid' into valid_subs
        file 'invalid' into invalid_subs


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

        with open('valid','w') as f:
            f.writelines("\\n".join(valid_subs))

        with open('invalid','w') as f:
            f.writelines("\\n".join(invalid_subs)) 
            f.write("\\n")

        """

    }


    //Write into main subject channel
    sub_channel = valid_subs
                        .splitText() { it.strip() }
}else{

    bids_channel.into(sub_channel)

}


// Filter out invalid subjects
process save_invocation{

    // Push input file into output folder

    input:
    file invocation from Channel.fromPath("$params.invocation")
    
    """
    cp ${params.invocation} ${params.out}
    """

}

process modify_invocation{
    
    // Takes a BIDS subject identifier
    // Modifies the template invocation json and outputs
    // subject specific invocation

    input:
    val sub from sub_channel

    output:
    file "${sub}.json" into invoke_json

    """

    #!/usr/bin/env python

    import json
    import sys

    out_file = '${sub}.json'
    invoke_file = '${params.invocation}'
    x = '${sub}'.replace('sub-','')

    with open(invoke_file,'r') as f:
        j_dict = json.load(f)
    
    j_dict.update({'participant_label' : [x]})

    with open(out_file,'w') as f:
        json.dump(j_dict,f,indent=4)

    """ 
    

}

process run_bids{

    input:
    file sub_input from invoke_json

    output:
    file '.command.*' into logs

    beforeScript "source /etc/profile"
    scratch true

    publishDir "$params.out/pipeline_logs/$params.application/", \
                 mode: 'copy', \
                 saveAs: { "$sub_input".replace('.json','.out')}, \
                 pattern: '.command.out'

    publishDir "$params.out/pipeline_logs", \
                 mode: 'copy', \
                 saveAs: { "$sub_input".replace('.json','.err')}, \
                 pattern: '.command.err'

    module 'slurm'

    shell:
    '''

    application=!{params.application}

    echo bosh exec launch \
    -v !{params.bids}:/bids \
    -v !{params.out}:/output \
    -v !{params.license}:/license \
    !{params.descriptor} $(pwd)/!{sub_input} \
    --imagepath !{params.simg} -x --stream

    bosh exec launch \
    -v !{params.bids}:/bids \
    -v !{params.out}:/output \
    -v !{params.license}:/license \
    !{params.descriptor} $(pwd)/!{sub_input} \
    --imagepath !{params.simg} -x --stream

    '''
}
