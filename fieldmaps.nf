
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

//Pull subjects and scans with ECHO ExportInfo tag
//And process into pairs
fieldmap_input = Channel.from(to_run)
                    .map { n -> [
                                    n,
                                    new File("$nifti_dir/$n").list()
                                                             .findAll { it.matches(".*${params.echo1}.*.nii.gz") }
                                                             .sort(),
                                    new File("$nifti_dir/$n").list()
                                                             .findAll { it.matches(".*${params.echo2}.*.nii.gz") }
                                                             .sort()
                                ] }
                    .filter { !it[1].isEmpty() }
                    .transpose()
                    .map { x,y,z -> [
                                        x,
                                        new File("$nifti_dir/$x/$y").toPath().toRealPath(),
                                        new File("$nifti_dir/$x/$z").toPath().toRealPath()
                                    ] }

// With list of inputs (sub,echo1,echo2) apply fieldmap processing!
process fieldmaps {

    module "FSL/5.0.11"

    publishDir "$params.out/$sub", \
                mode: 'copy', \
                pattern:  "magnitude.nii.gz" , \
                saveAs: { echo1.getName().replace("$params.echo1","MAG") }

    publishDir "$params.out/$sub", \
                mode: 'copy', \
                pattern:  "fieldmap.nii.gz" , \
                saveAs: { echo1.getName().replace("$params.echo1","FIELDMAP") }

    input:
    set val(sub), file(echo1), file(echo2) from fieldmap_input

    output:
    set val(sub), file("fieldmap.nii.gz"), file("magnitude.nii.gz") into fieldmap_output


    shell:
    '''
    #!/bin/bash

    FM65=!{echo1}
    FM85=!{echo2}

    ####split (pre) fieldmap files

    fslsplit ${FM65} split65 -t
    bet split650000 65mag -R -f 0.5 -m
    fslmaths split650002 -mas 65mag_mask 65realm
    fslmaths split650003 -mas 65mag_mask 65imagm

    fslsplit ${FM85} split85 -t
    bet split850000 85mag -R -f 0.5 -m
    fslmaths split850002 -mas 85mag_mask 85realm
    fslmaths split850003 -mas 85mag_mask 85imagm

    ####calc phase difference
    fslmaths 65realm -mul 85realm realeq1
    fslmaths 65imagm -mul 85imagm realeq2
    fslmaths 65realm -mul 85imagm imageq1
    fslmaths 85realm -mul 65imagm imageq2
    fslmaths realeq1 -add realeq2 realvol
    fslmaths imageq1 -sub imageq2 imagvol

    ####create complex image and extract phase and magnitude
    fslcomplex -complex realvol imagvol calcomplex
    fslcomplex -realphase calcomplex phasevolume 0 1
    fslcomplex -realabs calcomplex magnitude 0 1

    ####unwrap phase
    prelude -a 65mag -p phasevolume -m 65mag_mask -o phasevolume_maskUW

    ####divide by TE diff in seconds -> radians/sec
    fslmaths phasevolume_maskUW -div 0.002 fieldmap

    ####copy in geometry information
    fslcpgeom ${FM65} fieldmap.nii.gz -d
    fslcpgeom ${FM65} magnitude.nii.gz -d

    '''
}

