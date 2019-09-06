.. tigrlab_nextflow documentation master file, created by
   sphinx-quickstart on Mon Jul  8 12:26:36 2019.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

TIGRLab Pipelines: Utterly Reproducible Research (TIGR-PURR)
============================================================

Welcome to the documentation page for TIGR-PURR.
This is where you'll find information about how to run the lab's supported pipelines yourself as well as the various configuration options available to you.

TIGR-PURR is a pipeline system based off of `Nextflow <https://www.nextflow.io>`_. TIGR-PURR allows you to run various pipelines in a distributed fashion removing most of work dealing with cluster-specific scripting. Currently TIGR-PURR can be run on:

* The local Kimel-Lab Cluster
* CAMH's SCC Cluster
* Your local computer

.. note::
        Scinet's Niagara will be supported in an upcoming release!

A central feature of TIGR-PURR is its ability to run *any BIDS-application* through implementation of `Boutiques <https://www.boutiques.github.io>`_ under the hood. To learn about how you can run BIDS pipelines on any BIDS dataset check out :ref:`getting_started`. To go through an example running a BIDS application try the :ref:`quickstart_tutorial`


Finally, due to the needs for easily distributed post- and pre-processing of data that aren't applicable in the context of BIDS. TIGR-PURR is expanding outside of BIDS! Check out :ref:`not_bids` for information about non-BIDS-application pipelines (such as parallelized cifti_clean on ciftify outputs)

.. toctree::
   :maxdepth: 2
   :caption: Contents

   getting_started
   quickstart_tutorial
   quick_reference
   not_bids
   features
   changelog
