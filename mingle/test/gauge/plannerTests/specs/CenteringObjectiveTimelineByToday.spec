CenteringObjectiveTimelineByToday
=================================
tags: planner_views

Setup of contexts
* Login to mingle as "admin" - setup

CenteringObjectiveTimelineByToday
---------------------------------

Create a Plan And An Objective
* Create program "Finance Program" with plan from "1 Jan 2017" to "1 Jan 2020" and switch to days view
* Create objective "Payroll System" on "Finance Program" starts on "2017-01-01" and ends on "2020-01-01" in days view

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


