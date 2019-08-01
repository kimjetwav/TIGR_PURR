.. _changelog:

--------------------
Changes
--------------------

v1.0.1
====================

- [ENH] Switch to using ANSI supported logging instead of println utility in bids.nf
- [ENH] Filter subjects based on existing output directories to bids.nf
- [ENH] Add --rewrite option to bids.nf allowing for override of subject filtering
- [ENH] Invalid subjects list are now pushed to pipeline-specific logging directory
- [ENH] FeenICS pipeline (feenics.nf) implement gzip to mitigate issues with FSL auto-zipping
- [ENH] Implement orientation fix via scraping mri_info of freesurfer on each sprl scan prior to FeenICS
- [ENH] FeenICS now outputs logs in a consistent manner to bids.nf
- [ENH] FeenICS will filter already existing output directories
