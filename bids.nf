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

if (!params.subjects){

bids_channel = Channel
                    .from(all_dirs.list())
                    .filter { it.contains('sub-') }

}else {

sublist=file("$params.subjects")
bids_channel = Channel
                    .from(sublist)
                    .splitText() { it.strip() }
                    .filter { it.contains('sub-') }
}


process modify_invocation{
    
    // Takes a BIDS subject identifier
    // Modifies the template invocation json and outputs
    // subject specific invocation

    input:
    val sub from bids_channel

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
    file '.command.log' 

    beforeScript "source /etc/profile"
    scratch true
    publishDir "$params.out/logs", mode: 'move', saveAs: {"$sub_input".replace('.json','.log') }
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

// stdout into a log file
