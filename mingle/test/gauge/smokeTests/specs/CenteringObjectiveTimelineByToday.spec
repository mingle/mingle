CenteringObjectiveTimelineByToday
=================================

tags: #12995, group_a

Setup of contexts
* Login to mingle as "admin" - setup

CenteringObjectiveTimelineByToday
---------------------------------

Create a Plan And An Objective
* Create program "Finance Program" with plan from "1 Jan 2017" to "1 Jan 2019" and switch to days view
* Create objective "Payroll System" starts on "10 Jan 2017" and ends on "10 Aug 2017" in days view

Verify that timeline is centered on current day when the user is in days view
* Assert that the timeline is centered on today
Verify that timeline is centered on current day when the user is in Weeks view
* Switch to "weeks" view
* Assert that the timeline is centered on today
* Open plan "Finance Program"
* Assert that the timeline is centered on today

Verify that timeline is centered on current day when the user is in Months view
* Switch to "months" view
* Assert that the timeline is centered on today
* Open plan "Finance Program"
* Assert that the timeline is centered on today
* Assert granularity "months" highlighted
___

Teardown of contexts
* Login to mingle as "admin" - teardown


