// INPUT SPECIFICATION

if (!params.simg){
    log.info('Singularity container not specified!')
    log.info('Need --simg argument in Nextflow Call!')
    System.exit(1)

}

if (!params.derivatives) {

    log.info('Insufficient specification!')
    log.info('Need --derivatives!')
    System.exit(1)

}

if (!params.out) {

    log.info('Insufficient specification!')
    log.info('Need --out')

}

if (!params.derivative) {

    log.info('Please specify type of derivative!')
    log.info('Must be "fmriprep" or "ciftify"')


}


