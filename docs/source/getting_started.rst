.. _getting_started:

--------------------
Getting started
--------------------

In this section, we'll begin with where you can find regularly running standard pipelines. Then we will discuss how you can run your own standard pipeline (for example if you wanted outputs for a specific dataset quickly, although careful with space usage!). Finally we'll go over how you can customize arguments for either the BIDS application you want to run or SLURM if your requirements are more complex. 


Default Pipelines
============================

We run a set of **Default Pipelines** regularly on our internal data stores of which the outputs go directly into the archive. The default pipelines will always output into::

        /archive/data/<PROJECT>/pipelines/bids_apps/

All **Default Pipeline** outputs will be pushed into this directory. Each pipeline will contain its own subfolder here and the outputs contained within this subfolder are specific to the pipeline. For example::

        /archive/data/SPINS/pipelines/bids_apps/freesurfer/

Contains outputs from the `Freesurfer BIDS-app <https://github.com/BIDS-Apps/freesurfer>`_. The organization of the contents in this folder are specific to the Freesurfer BIDS-app and not anything specific to TIGRLab. If you have any questions about these outputs consult the user guide of the BIDS application of interest. If you still have questions then the Kimel Staff Team would be a good resource for more details.

Running your own Default Pipeline
====================================

Running your own default pipeline is simple with our set-up. First open up a terminal, then type in::

module load python/3.6.3-boutiques-0.5.20

This loads in `Boutiques <https://boutiques.github.io>`_ which is required by the TIGRLAB pipeline system.

.. note::

        For more details on what exactly Boutiques is doing consult the <INSERT BOUTIQUES SECTION> page. 

Once boutiques is loaded in you're ready to go! To run a pipeline some details are needed:

1. Your output directory
2. The BIDS folder that you'd like to run a pipeline on
3. A **Nextflow Configuration** file specifying which pipeline to run.


The **Nextflow Configuration** file is a short specification file which tells our pipeline system:

a. Which pipeline should be run
b. How to submit the job to SLURM (across different systems) if needed.

.. note::

        For more details surrounding how you too can make your own configuration file check out the <INSERT NEXTFLOW CONFIGURATION> page. 

**Default Pipeline** configuration files will always be found in::

        /archive/code/tigrlab_nextflow/nextflow_config

Here you will find a bunch of files that look like the following::

        fmriprep-1.3.2.nf.config
        fmriprep_ciftify-1.3.0-post2-2.3.1.nf.config
        freesurfer-6.0.1.nf.config
        mriqc-0.14.2.nf.config

Every **Nextflow Configuration** file ends with a ``*.nf.config`` and always begins with ``<bidsapp>-<version>``. This way you know exactly which version of a pipeline you're running!

Let's say we want to run the ``mriqc-0.14.2`` pipeline. Then running the pipeline is done with the following command::

        nextflow /archive/code/tigrlab_nextflow/bids.nf --bids <bids_dir> --out <output_dir> 

This will automatically submit SLURM jobs to the local Kimel cluster and run the **Default** MRIQC pipeline on the specified BIDS dataset. That's it! 


