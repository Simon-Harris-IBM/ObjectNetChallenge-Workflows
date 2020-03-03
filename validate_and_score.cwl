#!/usr/bin/env cwl-runner
#
# Example validate submission file
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python

inputs:

  - id: inputfile
    type: File?
  - id: test
    type: boolean?

arguments:
  - valueFrom: validate_and_score.py
  - valueFrom: $(inputs.inputfile)
    prefix: -f
  - valueFrom: results.json
    prefix: -o
  - valueFrom: $(inputs.test)
    prefix: -t

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
          import subprocess

          # currently hardcoding this for ObjectNet ids
          range_min = -1   # oid starts at 0, treat -1 as a valid noop value
          range_max = 312

          rval = { 'prediction_file_status': 'INVALID',
                   'prediction_errors': [] }

          def write_result_json(outfile, res):
              with open(outfile, 'w') as o:
                  o.write(json.dumps(res))

          def err_exit(err_msg):
              rval['prediction_errors'].append(err_msg)
              errresult = {'prediction_file_errors':"\n".join(rval['prediction_errors']),
                        'prediction_file_status':rval['prediction_file_status']}
              print(json.dumps(errresult, indent=2, sort_keys=True))
              write_result_json(args.output_file, errresult)
              sys.exit(0)

          parser = argparse.ArgumentParser()
          parser.add_argument("-f", "--filename", required=True, help="users result file")
          parser.add_argument("-r", "--range_check", action="store_true",default=False, help="reject entries that have out-of-range label indices")
          parser.add_argument("-o", "--output_file", help="Output JSON file")
          parser.add_argument("-t", "--test", default=False)

          try:
              args = parser.parse_args()
          except:
              err_exit('Failed to parse command line')

          # Run these commands to mount files into docker containers
          # docker run -v truth:/data/ --name helper busybox true
          # docker cp /ObjectNet-CONFIDENTIAL/answers_by_id.json helper:/data/answers_by_id.json
          if not test:
              subprocess.check_call(["docker", "cp", "helper:/data/answers_by_id.json",
                                    "answers.json"])
          else:
              subprocess.check_call(["docker", "cp", "helper:/data/answers-100-images.json",
                                    "answers.json"])

          try:
              with open("answers.json") as f:
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
                      #for x in row[1:6]:
                      for x in row[1:10:2]:
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

          result = {'prediction_file_errors':"\n".join(rval['prediction_errors']),
                    'prediction_file_status':rval['prediction_file_status']}
          result.update(results)
          
          #with open(args.output_file, 'w') as o:
          #    o.write(json.dumps(result))
          write_result_json(args.output_file, result)

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
