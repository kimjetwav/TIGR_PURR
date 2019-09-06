.. _changelog:

--------------------
Changes
--------------------

v1.1
===================
- [ENH] Added cifti_clean pipeline in ciftify/cifti_clean.nf allowing for post-processing of ciftify outputs
- [ENH] dMRIPREP now supported! 
- [FIX] Logs now output into base directory $params.out/pipeline_logs instead of in $params.out/$params.application
- [FIX] Better copying of invocation JSON to output directory without unexpected crashing from bash copy util
- [ENH] Added usage documentation to cifti_clean, planning on expanding to other Nextflow applications
- [ENH] Updated documentation since TIGR-PURR is expanding past just BIDS-apps
- [ENH] Switch to using ANSI supported logging instead of println utility in bids.nf
- [ENH] Filter subjects based on existing output directories to bids.nf
- [ENH] Add --rewrite option to bids.nf allowing for override of subject filtering
- [ENH] Invalid subjects list are now pushed to pipeline-specific logging directory
- [ENH] FeenICS pipeline (feenics.nf) implement gzip to mitigate issues with FSL auto-zipping
- [ENH] Implement orientation fix via scraping mri_info of freesurfer on each sprl scan prior to FeenICS
- [ENH] FeenICS now outputs logs in a consistent manner to bids.nf
- [ENH] FeenICS will filter already existing output directories
- [ENH] FeenICS can run on SCC/Kimel/Local
- [ENH] FeenICS now has profile configurations set up to submit on Kimel/Local/SCC
- [FIX] FeenICS will combine spiral scans after artifact removal
- [ENH] FeenICS strategy switched to ignore after failures to allow ICArus processing
- [ENH] Fieldmap pipeline added for computing fieldmaps on CAMH GE scans (TIGRLAB internal)
- [DOC] Updated TIGR-PURR documentation for non-BIDS internal pipelines
- [FIX] FeenICS had bug associated with uncontrolled file naming, issue is resolved
