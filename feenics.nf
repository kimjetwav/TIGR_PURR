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



//Overwrite
if (!params.rewrite) {
    log.info("--rewrite flag not used, will skip existing outputs")
}else{
    log.info("--rewrite flag is on! Will re-run on existing outputs!")
    log.info("If you want to completely re-run, please delete subject output")

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

//Get subjects
if (params.subjects){
    to_run = new File(params.subjects)
}else{
    to_run = input_sessions
}

//Filter subjects based on outputs if rewrite isn't specified
if (!params.rewrite) {
    to_run = to_run.findAll { !(output_sessions.contains(it)) }
}

//Filter for unavailable subjects if specified
if (params.subjects){

    //Pull non-empty inputs
    input_sub_channel = Channel.from(to_run)
                                .filter{ (it?.trim()) }

    process split_invalid{

            publishDir "$params.out/pipeline_logs/$params.application/", \
                     mode: 'copy', \
                     saveAs: { 'invalid_subjects.log' }, \
                     pattern: 'invalid'

            input:
            val subs from input_sub_channel.collect()
            val available_subs from Channel.from(input_sessions).collect()

            output:
            file 'valid' into valid_subs
            file 'invalid' optional true into invalid_subs


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

            if invalid_subs:

                with open('invalid','w') as f:
                    f.writelines("\\n".join(invalid_subs)) 
                    f.write("\\n")

            """

    }

    input_subs = valid_subs
                    .splitText() { it.strip() }


}else{
    input_subs = Channel.from(to_run)
}


sub_channel = input_subs
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
    container params.simg
    containerOptions "-B ${params.out}:${params.out}"
    
    input:
    set val(sub), file(sprlIN), file(sprlOUT) from oriented_subs

    output:
    file("exp/$sub") into melodic_out
    
    shell:
    '''

    #Set up logging
    logging_dir=!{params.out}/pipeline_logs/!{params.application}
    mkdir -p ${logging_dir}
    log_out=${logging_dir}/!{sub}.out
    log_err=${logging_dir}/!{sub}.err

    #Record task attempt
    echo "TASK ATTEMPT !{task.attempt}" >> ${log_out}
    echo "============================" >> ${log_out}
    echo "TASK ATTEMPT !{task.attempt}" >> ${log_err}
    echo "============================" >> ${log_err}

    #Set up folder structure
    mkdir -p ./exp/!{sub}/{sprlIN,sprlOUT}
    mv !{sprlIN} ./exp/!{sub}/sprlIN/
    mv !{sprlOUT} ./exp/!{sub}/sprlOUT/

    #Set up logging
    mkdir -p !{params.out}/feenics/logs
    logfile=!{params.out}/feenics/logs/!{sub}.log

    #Run FeenICS pipeline
    (
    s1_folder_setup.py $(pwd)/exp
    s2_identify_components.py $(pwd)/exp
    s3_remove_flagged_components.py $(pwd)/exp
    ) 2>> ${log_err} 1>> ${log_out}

    #combine spiral files
    combinesprl exp/

    #Move relevant files over
    mv exp/*sprlIN*nii.gz exp/!{sub}/
    mv exp/*sprlOUT*nii.gz exp/!{sub}/
    mv exp/*sprlCOMBINED*nii.gz exp/!{sub}/
    '''


}

process run_icarus{

    stageInMode 'copy'
    container params.simg

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

