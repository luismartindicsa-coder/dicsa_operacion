/// Daily arrival tolerance: after five minutes the full delay is recorded.
int hrEligibleLateMinutes(int minutes) => minutes > 5 ? minutes : 0;
