#!/usr/bin/env cwl-runner
#
# Express lane workflow
# Inputs:
#   submissionId: ID of the Synapse submission to process
#   adminUploadSynId: ID of a folder accessible only to the submission queue administrator
#   submitterUploadSynId: ID of a folder accessible to the submitter
#   workflowSynapseId:  ID of the Synapse entity containing a reference to the workflow file(s)
#
cwlVersion: v1.0
class: Workflow

requirements:
  - class: StepInputExpressionRequirement

inputs:
  - id: submissionId
    type: int
  - id: adminUploadSynId
    type: string
  - id: submitterUploadSynId
    type: string
  - id: workflowSynapseId
    type: string
  - id: synapseConfig
    type: File

# there are no output at the workflow engine level.  Everything is uploaded to Synapse
outputs: []

steps:

  get_docker_submission:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v2.1/get_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: filepath
      - id: docker_repository
      - id: docker_digest
      - id: entity_id
      - id: entity_type
      - id: results

  get_docker_config:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v2.1/get_docker_config.cwl
    in:
      - id: synapse_config
        source: "#synapseConfig"
    out: 
      - id: docker_registry
      - id: docker_authentication

#  download_goldstandard:
#    run: https://raw.githubusercontent.com/Sage-Bionetworks/synapse-client-cwl-tools/v0.1/synapse-get-tool.cwl
#    in:
#      - id: synapseid
#        #This is a dummy syn id, replace when you use your own workflow
#        valueFrom: "syn18081597"
#      - id: synapse_config
#        source: "#synapseConfig"
#    out:
#      - id: filepath

  validate_docker:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v2.1/validate_docker.cwl
    in:
      - id: docker_repository
        source: "#get_docker_submission/docker_repository"
      - id: docker_digest
        source: "#get_docker_submission/docker_digest"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: results
      - id: status
      - id: invalid_reasons

  annotate_docker_validation_with_output:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v2.1/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#validate_docker/results"
      - id: to_public
        default: true
      - id: force_change_annotation_acl
        default: true
      - id: synapse_config
        source: "#synapseConfig"
    out: [finished]

  check_status:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v2.1/check_status.cwl
    in:
      - id: status
        source: "#validate_docker/status"
      - id: previous_annotation_finished
        #source: "#annotate_validation_with_output/finished"
        source: "#annotate_docker_validation_with_output/finished"
      - id: previous_email_finished
        source: "#validation_email/finished"
    out: [finished]

  submit_to_challenge:
    run: submit_to_challenge.cwl
    in:
      - id: status
        source: "#validate_docker/status"
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: parentid
        source: "#submitterUploadSynId"
      - id: evaluationid
        valueFrom: "9614390"
      - id: previous_annotation_finished
        source: "#annotate_docker_validation_with_output/finished"
#      - id: previous_email_finished
#        source: "#validation_email/finished"
    out: []
