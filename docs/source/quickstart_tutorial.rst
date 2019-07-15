.. _quickstart_tutorial:


-------------------------------------------
TIGR-PURR Quickstart Tutorial
-------------------------------------------

This tutorial is meant to run you through a simple example of running TIGR-PURR pipelines on your computer. Please refer to :ref:`getting_started` for more detailed information.

Dry-Runs of Pipelines
=================================================================

In this quickstart tutorial we'll be running a **Dry-run** of  MRIQC on a bunch of participants from the SPINS study located in the archive. A Dry-run is a way of running pipelines without doing actual computation. It is mainly used to test that everything is working quickly before submitting a real job. Whenever you want to run a TIGR-PURR pipeline it is usually a good idea to perform a Dry-run prior to submission of the actual job. 


Most, if not all, BIDS-applications have an argument allowing you to run the pipeline dry. As such, we can run a pipeline dry by using the invocation JSON.

.. note::

        Specifying arguments for the BIDS-app can be found in :ref:`invocation`
        




