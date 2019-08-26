import groovy.json.JsonSlurper

//Print usage if --help option used
if (params.help) {

    usage = file("${baseDir.getParent()}/usage/cifti_clean_usage")
    default_simg = file(params.simg).getBaseName()

    bindings = ["simg":"$default_simg",
                "config":"$params.config"]

    engine = new groovy.text.SimpleTemplateEngine()
    toprint = engine.createTemplate(usage.text).make(bindings)
    print(toprint.toString())
    return

}

if (!params.simg){
    log.info('Singularity container not specified!')
    log.info('Need --simg argument in Nextflow Call!')
    return

}

if (!params.derivatives) {

    log.info('Insufficient specification!')
    log.info('Need --derivatives!')
    return

}

if (!params.out) {

    log.info('Insufficient specification!')
    log.info('Need --out')
    return

}

if (!params.type) {

    log.info('Please specify type of derivative using --type!')
    log.info('Must be "volume" or "surface"')
    return

}else if ( params.type != 'volume' && params.type != 'surface' ) {

    log.info('--type must be "volume" or "surface"')
    return

}

if (!params.config) {

    log.info("Insufficient specification")
    log.info("Need cifti cleaning config file --config")
    return

}

//Output specific parsing
basepath = "$params.derivatives/ciftify/sub-*/MNINonLinear/Results/*/"
if (params.type == "volume"){

    input_files = Channel.fromPath("$basepath/*nii.gz")

}else{

    input_files = Channel.fromPath("$basepath/*dtseries.nii")

}

//Use filtering
filtered_input = input_files
                        .filter { params.task ? it.getBaseName().contains(params.task) : true }


//If the user specifies surface and smoothwm is used then must attach additional files!
if (params.type == 'surface'){


    //Read in the cleaning config file
    config = new File(params.config)
    inputjson = new JsonSlurper().parse(config)
    smooth_enabled = inputjson.find { it.key == '--smooth-fwhm' }

    //If smoothing option is found, provide a left and right surface
    if smooth_enabled {

        //Regex match the subject directory then add L/R surfaces
        filtered_input = filtered_input
                                .map { n -> [
                                                n,
                                                (n =~ /sub-.+?(?=\/MNI)/)[0],
                                            ]
                                     }
                                .map { n,s ->   [
                                                    n,
                                                    s,
                                                    "$params.derivatives/$s/MNINonLinear/fsaverage_LR32k"
                                                ]
                                     }
                                .map { n,s,p ->   [
                                                    n,
                                                    file("$p/${s}.L.midthickness.surf.gii"),
                                                    file("$p/${s}.R.midthickness.surf.gii")
                                                ]
                                     }
    }

}

//If not using smoothing
process clean_file_no_smoothing {

    container "$params.simg"
    publishDir "$params.out", mode: 'move'

    input:
    file imagefile from filtered_input

    output:
    file "*_clean*" into cleaned_img

    when: 
    !smooth_enabled

    shell:
    '''
    ciftify_clean_img !{imagefile}    
    '''
    
}


//If using smoothing
process clean_file_smoothing {

    container "$params.simg"
    publishDir "$params.out", mode: 'move'

    input:
    set file(imagefile), file(L), file(R) from filtered_input

    output:
    file "*_clean*" into cleaned_img

    when: 
    smooth_enabled

    shell:
    '''
    ciftify_clean_img !{imagefile} --left-surface=!{L} --right-surface=!{R} 
    '''

}

