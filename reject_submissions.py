"""
Reject submissions that are invalid in main queue but valid in fanout queue
"""
import argparse

from challengeutils.utils import evaluation_queue_query
from challengeutils.utils import update_single_submission_status

import synapseclient


def _get_invalid_submissions(syn, queueid):
    """Get a submission queue's invalid submissions

    Args:
        syn: Synapse connection
        queueid: Evaluation queue id

    Returns:
        list of invalid submissions

    """
    query_str = (f"select name from evaluation_{queueid} where "
                  "status == 'INVALID'")
    submissions = list(evaluation_queue_query(syn, query_str))
    invalid_submissions = [sub['name'] for sub in submissions]
    return invalid_submissions


def change_status(syn, submissionid):
    status = syn.getSubmissionStatus(submissionid)

    set_status = {'prediction_file_status': 'INVALID'}
    new_status = update_single_submission_status(status, set_status,
                                                 is_private=False)
    new_status.status = "INVALID"
    syn.store(new_status)


def main(fanout_queue, main_queues):
    """Invoke REJECTION"""
    syn = synapseclient.login()
    # Get fanout queue validated submissions
    query_str = (f"select objectId from evaluation_{fanout_queue} where "
                 "status == 'ACCEPTED'")
    fanout_accepted = list(evaluation_queue_query(syn, query_str))
    # 'or' statements aren't allowed in this query service :(
    query_str = (f"select objectId from evaluation_{fanout_queue} where "
                 "prediction_file_status == 'EVALUATION_IN_PROGRESS'")
    fanout_evaluating = list(evaluation_queue_query(syn, query_str))
    fanout_accepted.extend(fanout_evaluating)
    fanout_submissions = set(sub['objectId'] for sub in fanout_accepted)

    # Get invalid main queue submissions
    invalid_submissions = []
    for main_queue in main_queues:
        invalid_submissions.extend(_get_invalid_submissions(syn, main_queue))

    for fanout_subid in fanout_submissions:
        # If fanout submission id matches a invalid submission
        # REJECT the fanout queue submission
        if fanout_subid in invalid_submissions:
            print(fanout_subid)
            change_status(syn, fanout_subid)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-f", "--fanout", required=True,
                        help="Fan out queue id")
    parser.add_argument("-m", "--main-queues", required=True, nargs='+',
                        help="Main queue ids")
    args = parser.parse_args()
    main(fanout_queue=args.fanout,
         main_queues=args.main_queues)