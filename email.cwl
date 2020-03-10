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
  - id: synapse_config
    type: File
  - id: status
    type: string
  - id: invalid_reasons
    type: string
  - id: results
    type: File

arguments:
  - valueFrom: validation_email.py
  - valueFrom: $(inputs.submissionid)
    prefix: -s
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c
  - valueFrom: $(inputs.status)
    prefix: --status
  - valueFrom: $(inputs.invalid_reasons)
    prefix: -i
  - valueFrom: $(inputs.results)
    prefix: -r

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: validation_email.py
        entry: |
          #!/usr/bin/env python
          import synapseclient
          import argparse
          import json
          import os
          parser = argparse.ArgumentParser()
          parser.add_argument("-s", "--submissionid", required=True, help="Submission ID")
          parser.add_argument("-c", "--synapse_config", required=True, help="credentials file")
          parser.add_argument("--status", required=True, help="Prediction File Status")
          parser.add_argument("-i","--invalid", required=True, help="Invalid reasons")
          parser.add_argument("-r", "--results", required=True, help="Resulting scores")

          args = parser.parse_args()
          syn = synapseclient.Synapse(configPath=args.synapse_config)
          syn.login()

          sub = syn.getSubmission(args.submissionid)
          status = syn.getSubmissionStatus(args.submissionid)
          result = filter(lambda x: x['key'] == "main_submitterId", status.annotations['stringAnnos'])
          participantid = list(result)[0]['value']
          try:
            name = syn.getTeam(participantid)['name']
          except Exception:
            name = syn.getUserProfile(participantid)['userName']
          evaluation = syn.getEvaluation(sub.evaluationId)

          if args.status == "INVALID":
            #subject = "Submission to '%s' invalid!" % evaluation.name
            subject = "ObjectNet Submission invalid!" 
            message = ["Hello %s,\n\n" % name,
                       "Your submission (%s) is invalid, below are the invalid reasons:\n\n" % sub.name,
                       args.invalid,
                       "\n\nSincerely,\nChallenge Administrator"]
          else:
            with open(args.results) as json_data:
              annots = json.load(json_data)
            #subject = "Submission to '%s' scored!" % evaluation.name
            subject = "ObjectNet Submission complete!"
            message = ["Hello %s,\n\n" % name,
                       "Your submission (%s) has been scored, below are your results:\n\n" % sub.name,
                       "\n".join([i + " : " + str(annots[i])
                                  for i in annots
                                  if i in ["accuracy", "top5_accuracy",
                                           "images_scored", "total_images"]]),
                       "\n\nSincerely,\nChallenge Administrator"]

          syn.sendMessage(userIds=[participantid],
                          messageSubject=subject,
                          messageBody="".join(message),
                          contentType="text")
          
outputs:
- id: finished
  type: boolean
  outputBinding:
    outputEval: $( true )
