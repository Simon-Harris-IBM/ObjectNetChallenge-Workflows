#!/usr/bin/env cwl-runner
#
# Example validate submission file
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python

hints:
  DockerRequirement:
    dockerPull: python:3.7

inputs:

  #- id: entity_type
  #  type: string
  - id: inputfile
    type: File?
  - id: goldstandard
    type: File

arguments:
  - valueFrom: validate_and_score.py
  - valueFrom: $(inputs.inputfile)
    prefix: -f
  - valueFrom: $(inputs.goldstandard.path)
    prefix: -a
  - valueFrom: result.json
    prefix: -o

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: validate_and_score.py
        entry: |
          #!/usr/bin/env python
          #import argparse
          #import json
          import os
          import sys
          import csv
          import json
          import argparse

          # currently hardcoding this for ObjectNet ids
          range_min = -1   # oid starts at 0, treat -1 as a valid noop value
          range_max = 312

          rval = { 'prediction_file_status': 'INVALID',
                   'prediction_file_errors': [] }

          def err_exit(err_msg):
              rval['prediction_file_errors'].append(err_msg)
              print(json.dumps(rval, indent=2, sort_keys=True))
              sys.exit(1)

          parser = argparse.ArgumentParser()
          parser.add_argument("-f", "--filename", required=True, help="users result file")
          parser.add_argument("-a", "--answers", required=True, help="ground truth/answer file")
          parser.add_argument("-r", "--range_check", action="store_true", help="reject entries that have out-of-range label indices")
          parser.add_argument("-o", "--output_file", help="Output JSON file")
          #parser.add_argument("-s", "--submission_file", help="Submission File")

          # NEW VALIDATION CODE HERE
          #args = parser.parse_args()
          try:
              args = parser.parse_args()
          except:
              err_exit('Failed to parse command line')

          #if args.filename is None:
          #    prediction_file_status = "INVALID"
          #    invalid_reasons = ['Expected FileEntity type but found ' + args.entity_type]
          #else:
          #with open(args.submission_file,"r") as sub_file:
          #    message = sub_file.read()
          #invalid_reasons = []
          #prediction_file_status = "VALIDATED"
          # This is where the validation code should go
          #if not message.startswith("test"):
          #    invalid_reasons.append("Submission must have test column")
          #    prediction_file_status = "INVALID"

          # New validate & score code
          #try:
          #    args = parser.parse_args()
          #except:
          #    err_exit('Failed to parse command line')

          #args.answers = os.environ['GOLD_LABELS']
          try:
              with open(args.answers) as f:
                  answers = json.load(f)
              total = len(answers)
          except:
              err_exit('ObjectNet answer file not available')

          try:
              f = open(args.filename)
          except:
              err_exit('Unable to open results file: {}'.format(args.filename))

          try:
              reader = csv.reader(f)
          except:
              err_exit('Unable to open results file as csv file: {}'.format(args.filename))

          try:
              linecnt = 0
              num_correct = 0
              num5_correct = 0
              found = set()
              for row in reader:
                  try:
                      filename = os.path.split(row[0])[1] # remove dir if necessary
                  except:
                      err_exit('Failure to convert first csv column to string')
                  if filename not in answers:
                      err_exit('Image name in first csv column not found in answer set')
                  if filename in found:
                      err_exit('Duplicate image name in result csv..rejecting')
                  found.add(filename)

                  correct = answers[filename]
                  try:
                      pred = []
                      for x in row[1:6]:
                          if x == '':   # allow empty predictions
                              pred.append(-1)
                          else:
                              pred.append(int(x))
                  except Exception as e:
                      # not really happy about swallowing exception, how to dump it w/o the submitter seeing it??
                      # print(e, file=sys.stderr)
                      err_exit('Failure to convert predictions to integer indices')
                  if args.range_check:
                      for p in pred:
                          if p < range_min or p > range_max:
                              err_exit('Prediction index <{}> out of range [{}, {}]'.format(p, range_min, range_max))
                  if pred[0] == correct:
                      num_correct += 1
                  if correct in pred:
                      num5_correct += 1
                  linecnt += 1
          except Exception as e:
              # not really happy about swallowing exception, how to dump it w/o the submitter seeing it??
              # print(e, file=sys.stderr)
              err_exit('Caught exception while parsing csv file: {}'.format(args.filename))

          results = { 'accuracy': 100.0 * num_correct / total,
                      'top5_accuracy': 100.0 * num5_correct / total,
                      'images_scored': linecnt,
                      'total_images': total }
          rval.update(results)
          rval['prediction_file_status'] = 'VALIDATED'
          print(json.dumps(rval, indent=2, sort_keys=True))
          sys.exit(0)

          #result = {'prediction_file_errors':"\n".join(invalid_reasons),'prediction_file_status':prediction_file_status}
          with open(args.output_file, 'w') as o:
              o.write(json.dumps(rval))

outputs:

  - id: results
    type: File
    outputBinding:
      glob: results.json

  - id: status
    type: string
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['prediction_file_status'])

  - id: invalid_reasons
    type: string
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['prediction_file_errors'])
