// INPUT SPECIFICATION
// Don't use study, allow input to be specified freely
if (!params.simg){
    println('Singularity container not specified!')
    println('Need --simg argument in Nextflow Call!')
    System.exit(1)

}

if (!params.bids || !params.out || !params.work) {

    println('Insufficient specification!')
    println('Need  --bids, --out and --tmp!')
    System.exit(1)

}

println("BIDS Directory: $params.bids")
println("Output directory: $params.out")
println("Workdir: $params.work")


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

//////////////////////////////////////////////////////////////

// Main Processes

all_dirs = file(params.bids)
bids_channel = Channel
                    .from(all_dirs.list())
                    .filter { it.contains('sub') }
                    .take(3)

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

    beforeScript "source /etc/profile"

    echo true
    
    module 'slurm'
    module '/archive/code/packages.module'

    input:
    file sub_input from invoke_json

    shell:
    '''

    workdir=!{params.work}
    application=!{params.application}

    mkdir -p $workdir
    tmpdir=$(mktemp -d $workdir/$application.XXXXX)
    echo $tmpdir

    echo bosh exec launch \
    -v !{params.bids}:/bids \
    -v !{params.out}:/output \
    -v ${tmpdir}:/work_dir \
    -v !{params.license}:/license \
    !{params.descriptor} $(pwd)/!{sub_input} \
    --imagepath !{params.simg} -x

    '''
}
