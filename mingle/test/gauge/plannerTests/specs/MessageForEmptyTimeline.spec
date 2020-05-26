MessageForEmptyTimeline
=======================

tags: planner_views

Setup of contexts
* Login to mingle as "admin" - setup
* Create program with objectives "Finance Program" "" - setup

MessageForEmptyTimeline
-----------------------

Display an Objective creation popup on an empty timeline
* Open plan "Finance Program" in days view
* Assert indication for empty timeline view does not appear
* Assert create objective popup is displayed

Display the informational message when the new Objective popup is closed on an empty timeline
* Close objective creation popup
* Assert indication for empty timeline view appears
* Assert create objective popup is not displayed

The Objective creation popup and informational message are not visible when an objective is created
* Create objective "Payroll System" on "Finance Program" starts on "1 Jan 2011" and ends on "5 Jan 2011" in days view
* Assert text present "Click on the timeline to create your first feature."
* Assert create objective popup is not displayed



___

Teardown of contexts
* Create program with objectives "Finance Program" "" - teardown
* Login to mingle as "admin" - teardown


