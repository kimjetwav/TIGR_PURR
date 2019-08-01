// INPUT SPECIFICATION
// Feed in study from DATMAN and process all sessions

//TO-DO: Set up logging of subject information

if (!params.study || !params.out){

    log.info("Insufficient specification")
    log.info("Both --study and --out are required!")
    System.exit(1)


}

log.info("Output directory: $params.out")

if (params.subjects) {

    log.info("Subject file provided: $params.subjects")

}


// Main processes
//nifti directory
nifti_dir="/archive/data/$params.study/$params.nii"

//Inputs
input_sessions_dir = new File(nifti_dir)
input_sessions = input_sessions_dir.list()

//Outputs
output_sessions_dir = new File(params.out)
output_sessions = output_sessions_dir.list()

//Filter for un-run sessions
to_run = input_sessions.findAll { !(output_sessions.contains(it)) }


//Pull subjects and scans containing SPRL-IN/SPRL-OUT
sub_channel = Channel.from(to_run)
                        .map { n -> [
                                        n,
                                        new File("$nifti_dir/$n").list()
                                                                 .findAll { it.contains("SPRL-IN") || 
                                                                            it.contains("SPRL-OUT") }
                                                                 .sort()
                                    ]
                             }   
                        .filter { !it[1].isEmpty() }
                        .map { n -> [ 
                                        
                                        n[0],
                                        new File("$nifti_dir/${n[0]}/${n[1][0]}").toPath().toRealPath(),
                                        new File("$nifti_dir/${n[0]}/${n[1][1]}").toPath().toRealPath()
                                    ]
                             }
                        .take(3)
                        //.subscribe { log.info it }

//GZIP files
process gzip_nii {

    stageInMode 'copy'
    
    input:
    set val(sub), file(sprlIN), file(sprlOUT) from sub_channel

    output:
    set val(sub), file("${sprlIN}.gz"), file("${sprlOUT}.gz") into gzipped_channel

    shell:
    '''
    gzip !{sprlIN} 
    gzip !{sprlOUT}
    '''

}

//Pre-process components with PRS orientation indicating they need to be reoriented
process reorient_bad {

    module 'freesurfer'
    module 'FSL/5.0.11'
    stageInMode 'copy'

    input:
    set val(sub), file(sprlIN), file(sprlOUT) from gzipped_channel

    output:
    set val(sub), file(sprlIN), file(sprlOUT) into oriented_subs

    shell:
    '''
    #!/bin/bash
    
    orientation=$(mri_info --orientation !{sprlIN})

    if [ "$orientation" = "PRS" ]; then

        fslorient -deleteorient !{sprlIN}
        fslorient -deleteorient !{sprlOUT}

        fslswapdim !{sprlIN} -x -y z  !{sprlIN}
        fslswapdim !{sprlOUT} -x -y z !{sprlOUT}

        fslorient -setqformcode 1 !{sprlIN}
        fslorient -setqformcode 1 !{sprlOUT}

        #Save list of reoriented scans
        mkdir -p !{params.out}/feenics/logs
        reorient_list=!{params.out}/feenics/logs/reoriented.log
        echo !{sub} >> $reorient_list

    fi
    '''


}


//Run subject level FeenICS
process run_feenics{

    container "$params.simg"
    stageInMode 'copy'
    scratch "/tmp/"
    containerOptions "-B ${params.out}:${params.out}"
    
    input:
    set val(sub), file(sprlIN), file(sprlOUT) from oriented_subs

    output:
    file("exp/$sub") into melodic_out
    
    shell:
    '''
    #Set up folder structure
    mkdir -p ./exp/!{sub}/{sprlIN,sprlOUT}
    mv !{sprlIN} ./exp/!{sub}/sprlIN/
    mv !{sprlOUT} ./exp/!{sub}/sprlOUT/

    #Set up logging
    mkdir -p !{params.out}/feenics/logs
    logfile=!{params.out}/feenics/logs/!{sub}.log

    #Run FeenICS pipeline
    s1_folder_setup.py $(pwd)/exp >> $logfile 
    s2_identify_components.py $(pwd)/exp >> $logfile
    s3_remove_flagged_components.py $(pwd)/exp >> $logfile

    #Move spiral files over to subject directory
    mv exp/*nii.gz exp/!{sub}/


    '''


}


process run_icarus{

    stageInMode 'copy'

    container "$params.simg"
    publishDir "$params.out/feenics", \
                mode: 'copy'
             

    input:
    file "*" from melodic_out.collect()

    output:
    file "qc_icafix.html" into icarus_out
    file "ica_fix_report_fix4melview_Standard_thr20.csv" into fix_report
    file "*/*" into sprl_out
    
    echo true

    shell:
    '''
    #!/bin/bash

    sprls=$(ls -1d */sprl*/)
    icarus-report ${sprls}

    '''

}

