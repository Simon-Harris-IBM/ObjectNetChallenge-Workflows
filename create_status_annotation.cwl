#!/usr/bin/env cwl-runner
#
# Create an annotation json with the status of submission
#
cwlVersion: v1.0
class: CommandLineTool
# Needs a basecommand, so use echo as a hack
baseCommand: echo

inputs:
  - id: status
    type: string

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: update_status.json
        entry: |
          {"prediction_file_status": \"$(inputs.status)\"}

outputs:
  - id: json_out
    type: File
    outputBinding:
      glob: update_status.json