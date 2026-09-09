/// Daily eligibility, before period totals. Once eligible, all minutes count.
int hrEligibleOvertimeMinutes(int minutes) => minutes > 15 ? minutes : 0;
