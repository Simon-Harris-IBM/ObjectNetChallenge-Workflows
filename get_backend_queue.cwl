#!/usr/bin/env cwl-runner
#
# Selects the back-end queue to send the submission to
# when using fan-out technique.
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python3

hints:
  DockerRequirement:
    dockerPull: sagebionetworks/synapsepythonclient:v1.9.2

inputs:
  - id: queueids
    type: string[]
  - id: synapse_config
    type: File

arguments:
  - valueFrom: get_backend_queue.py
  - valueFrom: $(inputs.queueids)
    prefix: -q
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c

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
          import time

          import synapseclient

          # It appears a workflow requires at least one argument so
          # keep the following lines either though we don't use
          # the argument.
          parser = argparse.ArgumentParser()
          parser.add_argument("-q", "--queues", required=True, help="List of queues", nargs='+')
          parser.add_argument("-c", "--synapse_config", required=True, help="credentials file")
          args = parser.parse_args()
          syn = synapseclient.Synapse(configPath=args.synapse_config)
          syn.login()

          free_queues = []
          # Append to free queues when a free queue opens up
          # If free queues list is empty, continually look for free queues
          while not free_queues:
            time.sleep(30)
            for queue in args.queues:
              # list submissions that are evaluation in progress
              evaluating_submissions = list(syn.getSubmissionBundles(queue, status="EVALUATION_IN_PROGRESS"))
              if not evaluation_submissions:
                free_queues.append(queue)

          # Randomly select free queue
          qid = random.choice(free_queues)
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
