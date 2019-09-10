nextflow.preview.dsl=2


process get_bids_subjects{

    /*
    Returns a channel containing BIDS subjects
    */

    input:
    file 'bids'

    //Can we stick an additional process?
    //Add filtering? etc...?
    output:
    file 'subs.txt'

    shell:
    '''
    #!/usr/bin/env python

    import bids

    layout = bids.BIDSLayout("bids")
    '''

process filter_invalid_subjects{

    /*
    Filter out invalid subjects not available in the given directory
    Will also record outputs into a text file which is pushed into a channel
    */

    input:
    val subs
    val available_subs

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
