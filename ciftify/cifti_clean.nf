import groovy.json.JsonSlurper

print_help = false

usage = file("${baseDir.getParent()}/usage/cifti_clean_usage")
default_simg = file(params.simg).getBaseName()
bindings = ["simg":"$default_simg",
            "config":"$params.config"]

engine = new groovy.text.SimpleTemplateEngine()
toprint = engine.createTemplate(usage.text).make(bindings)

//Print usage if --help option used
if (params.help) {

    print(toprint)
    return

}

if (!params.simg){

    log.info('Singularity container not specified!')
    log.info('Need --simg argument in Nextflow Call!')
    print_help = true

}

if (!params.derivatives) {

    log.info('Insufficient specification!')
    log.info('Need --derivatives!')
    print_help = true

}

if (!params.out) {

    log.info('Insufficient specification!')
    log.info('Need --out')
    print_help = true

}

if (!params.type) {

    log.info('Please specify type of derivative using --type!')
    log.info('Must be "volume" or "surface"')
    print_help = true

}else if ( params.type != 'volume' && params.type != 'surface' ) {

    log.info('--type must be "volume" or "surface"')
    print_help = true

}

if (!params.config) {

    log.info("Insufficient specification")
    log.info("Need cifti cleaning config file --config")
    print_help = true

}

if (print_help) {

    print(toprint)
    return

}

//Output specific parsing
basepath = "$params.derivatives/ciftify/sub-*/MNINonLinear/Results/*/"
if (params.type == "volume"){

    input_files = Channel.fromPath("$basepath/*nii.gz").take(1)

}else{

    input_files = Channel.fromPath("$basepath/*dtseries.nii").take(1)

}

//Use filtering
no_smooth_input = Channel.create()
smooth_input = Channel.create()
confounds_matcher = Channel.create()

//Get associated L/R midthickness files
smooth_input =  input_files
                        .filter { params.task ? it.getBaseName().contains(params.task) : true }
                        .tap ( no_smooth_input )
                        .map { n -> [
                                        n,
                                        (n =~ /sub-.+?(?=\/MNI)/)[0],
                                    ]
                             }
                        .tap ( confounds_matcher )
                        .map { n,s ->   [
                                            n,
                                            s,
                                            "$params.derivatives/ciftify/$s/MNINonLinear/fsaverage_LR32k",
                                        ]
                             }
                        .map { n,s,p ->   [
                                            n,
                                            file("$p/${s}.L.midthickness.surf.gii"),
                                            file("$p/${s}.R.midthickness.surf.gii")
                                        ]
                             }


map_2_no_smooth = Channel.create()
map_2_smooth = Channel.create()
confounds_matched = confounds_matcher
                            //Pull session information and description of task
                            .map { n, s -> [
                                            n,
                                            s,
                                            (n =~ /ses-.+?(?=_)/)[0],
                                            file(n).getParent().getName().replace('preproc','confounds_regressors.tsv')
                                           ]
                                 }
                            //Map to confounds
                            .map { n, s, e, d ->    [
                                                        n,
                                                        file("$params.derivatives/fmriprep/$s/$e/func/${s}_${d}")
                                                    ]
                                 }
                            .into { map_2_no_smooth; map_2_smooth }

no_smooth_input = no_smooth_input.join(map_2_no_smooth)
smooth_input = smooth_input.join(map_2_smooth)


//Flag for whether to use smoothing or not
if (params.type == 'surface'){

    //Read in the cleaning config file
    config = new File(params.config)
    inputjson = new JsonSlurper().parse(config)
    smooth_enabled = inputjson.find { it.key == '--smooth-fwhm' }

}

//If not using smoothing
process clean_file_no_smoothing {

    container "$params.simg"
    publishDir "$params.out", mode: 'move'


    input:
    set file(imagefile), file(confounds) from no_smooth_input
    file "config.json" from file(params.config)

    output:
    file "*_clean*" into unsmoothed_cleaned_img
    file "config.json" into unsmoothed_config

    when: 
    !(smooth_enabled)

    shell:
    '''
    ciftify_clean_img !{imagefile} \
                     --clean-config config.json \
                     --confounds-tsv !{confounds}
    '''
    
}

//If using smoothing
process clean_file_smoothing {

    container "$params.simg"
    publishDir "$params.out", mode: 'move'

    input:
    set file(imagefile), file(L), file(R), file(confounds) from smooth_input
    file "config.json" from file(params.config)

    output:
    file "*_clean*" into smoothed_cleaned_img
    file "config.json" into smoothed_config

    when: 
    (smooth_enabled)

    shell:
    '''
    ciftify_clean_img !{imagefile} \
                    --left-surface=!{L} \
                    --right-surface=!{R} \
                    --clean-config config.json \
                    --confounds-tsv !{confounds}
    '''

}

