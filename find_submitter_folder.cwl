#!/usr/bin/env cwl-runner
#
# Extract the submitted Docker repository and Docker digest
# And submitterSynid and adminUploadSynId
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python

hints:
  DockerRequirement:
    dockerPull: sagebionetworks/synapsepythonclient:v1.9.4

inputs:
  - id: submissionid
    type: int
  - id: synapse_config
    type: File

arguments:
  - valueFrom: find_submitter_folder.py
  - valueFrom: $(inputs.submissionid)
    prefix: -s
  - valueFrom: results.json
    prefix: -r
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: find_submitter_folder.py
        entry: |
          #!/usr/bin/env python
          import synapseclient
          import argparse
          import json
          import os
          parser = argparse.ArgumentParser()
          parser.add_argument("-s", "--submissionid", required=True, help="Submission ID")
          parser.add_argument("-r", "--results", required=True, help="download results info")
          parser.add_argument("-c", "--synapse_config", required=True, help="credentials file")
          args = parser.parse_args()
          syn = synapseclient.Synapse(configPath=args.synapse_config)
          syn.login()
          sub = syn.getSubmission(args.submissionid, downloadLocation=".")
          
          if sub.get("teamId") is not None:
            submitterid = sub.get("teamId")
          else:
            submitterid = sub.get("userId")
          submitters = syn.getChildren("syn21445379")
          for submitter in submitters:
            if submitter['name'] == submitterid:
              submitter_folder = submitter['id']
              break
          submissions = syn.getChildren(submitter_folder)
          for submission in submissions:
            if submission['name'] == sub.id:
              submitter_folder = submission['id']
          result = {'orgSagebionetworksSynapseWorkflowOrchestratorSubmissionFolder': submitter_folder}
          with open(args.results, 'w') as o:
            o.write(json.dumps(result))

outputs:
  - id: results
    type: File
    outputBinding:
      glob: results.json
