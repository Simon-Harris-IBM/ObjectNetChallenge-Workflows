#!/usr/bin/env cwl-runner
#
# Selects the back-end queue to send the submission to
# when using fan-out technique.
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python

inputs:
  - id: queueids
    type: string

arguments:
  - valueFrom: get_backend_queue.py
  - valueFrom: $(inputs.queueids)
    prefix: -q

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: get_backend_queue.py
        entry: |
          #!/usr/bin/env python
          import argparse
          import json
          import os
          import random

          # It appears a workflow requires at least one argument so
          # keep the following lines either though we don't use
          # the argument.
          parser = argparse.ArgumentParser()
          parser.add_argument("-q", "--queues", required=True, help="List of queues")
          args = parser.parse_args()
          # Just randomly select queue for now.
          # Need to implement at the very least a round robin technique.
          qid = random.choice(["9614390","9614420"])
          #qid = random.choice(queues)
          q_json = {'qid': qid}
          with open('q.json', 'w') as o:
            o.write(json.dumps(q_json))
          print("=> Sending to backend queue: ", q_json)

outputs:
- id: qid
  type: string
  outputBinding:
    glob: q.json
    loadContents: true
    outputEval: $(JSON.parse(self[0].contents)['qid'])
