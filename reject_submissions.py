"""
Reject submissions that are invalid in main queue but valid in fanout queue
"""
import argparse

from challengeutils.utils import evaluation_queue_query
from challengeutils.utils import change_submission_status
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


def main(fanout_queue, main_queues):
    """Invoke REJECTION"""
    syn = synapseclient.login()
    # Get fanout queue validated submissions
    query_str = (f"select objectId from evaluation_{fanout_queue} where "
                  "prediction_file_status == 'VALIDATED' "
                  "and status == 'ACCEPTED'")
    fanout_submissions = list(evaluation_queue_query(syn, query_str))

    # Get invalid main queue submissions
    invalid_submissions = []
    for main_queue in main_queues:
        invalid_submissions.extend(_get_invalid_submissions(syn, main_queue))

    for sub in fanout_submissions:
        fanout_subid = sub['objectId']
        # If fanout submission id matches a invalid submission
        # REJECT the fanout queue submission
        if fanout_subid in invalid_submissions:
            print(fanout_subid)
            change_submission_status(syn, fanout_subid, "REJECTED")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-f", "--fanout", required=True,
                        help="Fan out queue id")
    parser.add_argument("-m", "--main-queues", required=True, nargs='+',
                        help="Main queue ids")
    args = parser.parse_args()
    main(fanout_queue=args.fanout,
         main_queues=args.main_queues)