RememberTheView
===============

tags: planner_views

Setup of contexts
* Login to mingle as "admin" - setup
* Create program with objectives "Finance Program" "Payroll System" - setup

RememberTheView
---------------

Story #11546 "Remember the timeline level that you are on"
Story #11493 "View plan timeline at monthly level"

Remember the timeline level whe user navigates planner
* Open plan "Finance Program" in days view
* Assert granularity "days" highlighted
* Switch to "weeks" view
* Navigate to program "Finance Program" projects page
* Open "Plan" page
* Assert granularity "weeks" highlighted
* Switch to "months" view
* Open "Projects" page
* Open "Plan" page
* Assert granularity "months" highlighted
* Create plan in program "Court Management"
* Assert granularity "months" highlighted

Remember the timeline level when user logs out and logs in Mingle
* Logout mingle
* Login as "admin"
* Open plan "Finance Program" in days view
* Assert granularity "days" highlighted

Other users still lands on Months view.
* Add full team member "member" to program "Finance Program"
* Logout mingle
* Login as "member"
* Open plan "Finance Program" via url
* Assert granularity "months" highlighted


___

Teardown of contexts
* Create program with objectives "Finance Program" "Payroll System" - teardown
* Login to mingle as "admin" - teardown


