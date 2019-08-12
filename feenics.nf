// INPUT SPECIFICATION
// Feed in study from DATMAN and process all sessions


if (!params.study || !params.out){

    println("Insufficient specification")
    println("Both --study and --out are required!")
    System.exit(1)


}

println("Output directory: $params.out")

if (params.subjects) {

    println("Subject file provided: $params.subjects")

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
                        //.subscribe { println it }


//Run subject level FeenICS
process run_feenics{

    stageInMode 'copy'
    scratch "/tmp/"
    
    input:
    set val(sub), file(sprlIN), file(sprlOUT) from sub_channel

    output:
    file("exp/$sub") into melodic_out
    
    shell:
    '''
    #Set up folder structure
    mkdir -p ./exp/!{sub}/{sprlIN,sprlOUT}
    mv !{sprlIN} ./exp/!{sub}/sprlIN/sprlIN.nii
    mv !{sprlOUT} ./exp/!{sub}/sprlOUT/sprlOUT.nii

    #Run FeenICS pipeline
    s1_folder_setup.py $(pwd)/exp
    s2_identify_components.py $(pwd)/exp
    s3_remove_flagged_components.py $(pwd)/exp

    #Move spiral files over to subject directory
    mv exp/*nii.gz exp/!{sub}/

    #Combine spiral files
    combinesprl exp/!{sub}/
    '''


}


process run_icarus{

    stageInMode 'copy'

    publishDir "$params.out", \
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

