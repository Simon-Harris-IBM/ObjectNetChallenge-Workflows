#!/usr/bin/env cwl-runner
#
# Example sends validation emails to participants
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python3

hints:
  DockerRequirement:
    dockerPull: sagebionetworks/synapsepythonclient:v1.9.2

inputs:
  - id: submissionid
    type: int
  - id: fanoutid
    type: int
  - id: synapse_config
    type: File
  - id: parentid
    type: string

arguments:
  - valueFrom: notify_email.py
  - valueFrom: $(inputs.submissionid)
    prefix: -s
  - valueFrom: $(inputs.fanoutid)
    prefix: -f
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c
  - valueFrom: $(inputs.parentid)
    prefix: -p

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: notify_email.py
        entry: |
          #!/usr/bin/env python
          import synapseclient
          import argparse
          import json
          import os
          parser = argparse.ArgumentParser()
          parser.add_argument("-f", "--fanoutid", required=True, help="Fanout Submission ID")
          parser.add_argument("-s", "--submissionid", required=True, help="Submission ID")
          parser.add_argument("-c", "--synapse_config", required=True, help="credentials file")
          parser.add_argument("-p","--parentid", required=True, help="Parent Id of participant folder")

          args = parser.parse_args()
          syn = synapseclient.Synapse(configPath=args.synapse_config)
          syn.login()

          sub = syn.getSubmission(args.fanoutid)
          participantid = sub.get("teamId")
          if participantid is not None:
            name = syn.getTeam(participantid)['name']
          else:
            participantid = sub.userId
            name = syn.getUserProfile(participantid)['userName']
          main = syn.getSubmission(args.submissionid)
          evaluation = syn.getEvaluation(main.evaluationId)

          subject = "Submission Running on '%s'!" % evaluation.name
          message = ["Hello %s,\n\n" % name,
                     "Your results can be found here: https://www.synapse.org/#!Synapse:%s !\n\n" % args.parentid,
                     "\nSincerely,\nChallenge Administrator"]

          syn.sendMessage(userIds=[participantid],
                          messageSubject=subject,
                          messageBody="".join(message),
                          contentType="text")
          
outputs:
- id: finished
  type: boolean
  outputBinding:
    outputEval: $( true )
