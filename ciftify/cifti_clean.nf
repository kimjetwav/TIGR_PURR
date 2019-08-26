// INPUT SPECIFICATION

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

//Now process using cifti cleaning
process clean_file {

    container "$params.simg"
    publishDir "$params.out", mode: 'move'

    input:
    file imagefile from filtered_input

    output:
    file "*_clean*" into cleaned_img

    shell:
    '''
    ciftify_clean_img !{imagefile}    
    '''
    
}
