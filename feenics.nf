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
    //scratch "/tmp/"

    publishDir "$params.out/${sub}/", \
                 mode: 'move', \
                 pattern: '*sprl*.nii.gz', \
                 saveAs: { it.replace(".nii.gz","_denoised.nii.gz") }
    
    echo true

    input:
    set val(sub), file(sprlIN), file(sprlOUT) from sub_channel

    output:
    set file("*sprlIN*"), file("*sprlOUT*") into denoised_sprls
    file("exp/$sub") into melodic_out
    
    shell:
    '''
    #Set up folder structure
    mkdir -p ./exp/!{sub}/{sprlIN,sprlOUT}
    error
    mv !{sprlIN} ./exp/!{sub}/sprlIN/sprlIN.nii
    mv !{sprlOUT} ./exp/!{sub}/sprlOUT/sprlOUT.nii

    cw=$(pwd)

    #Run FeenICS stages?
    s1_folder_setup.py $(pwd)/exp

    #Run twice??
    cd $cw
    s2_identify_components.py $(pwd)/exp

    #Finish
    cd $cw
    s3_remove_flagged_components.py $(pwd)/exp

    #Move files for staging
    cd $cw
    mv exp/*nii.gz $(pwd)/
    '''


}

//No longer needed
denoised_sprls.close()

//Run ICArus -- although might need to be run custom post? 
melodic_out
        .subscribe { log.info("$it") }




