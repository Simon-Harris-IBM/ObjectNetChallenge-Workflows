#!/usr/bin/env cwl-runner
#
# Selects the back-end queue to use when using fan-out technique
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python

inputs:
  - id: queueids
    type: string
#  - id: synapse_config
#    type: File

arguments:
  - valueFrom: get_backend_queue.py
  - valueFrom: $(inputs.queueids)
    prefix: -q
#  - valueFrom: get_linked_submissionid.py
#  - valueFrom: $(inputs.submissionid)
#    prefix: -s
#  - valueFrom: $(inputs.synapse_config.path)
#    prefix: -c

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: get_backend_queue.py
        entry: |
          #!/usr/bin/env python
          #import synapseclient
          import argparse
          import json
          import os

          import random
          parser = argparse.ArgumentParser()
          parser.add_argument("-q", "--queues", required=True, help="List of queues")
          #parser.add_argument("-c", "--synapse_config", required=True, help="credentials file")
          args = parser.parse_args()
          #syn = synapseclient.Synapse(configPath=args.synapse_config)
          #syn.login()
          #sub = syn.getSubmission(args.submissionid, downloadLocation=".")
          # use args.queues below
          qid = random.choice(["9614390","9614420"])
          q_json = {'qid': qid}
          with open('q.json', 'w') as o:
            o.write(json.dumps(q_json))
          print("=> Sending to backend queue: ", q_json)

outputs:
- id: qid
  type: string
  outputBinding:
    # This tool depends on the submission.json to be named submission.json
    glob: q.json
    loadContents: true
    outputEval: $(JSON.parse(self[0].contents)['qid'])
#  - id: qid
#    type: File
#    outputBinding:
#      # This tool depends on the submission.json to be named submission.json
#      glob: selected_queue.json
#      loadContents: true
#      outputEval: $(JSON.parse(self[0].contents)['qid'])
