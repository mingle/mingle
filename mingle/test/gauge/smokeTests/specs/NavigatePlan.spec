NavigatePlan
============

tags: #11402, plan navigation, #11447, group_a

Setup of contexts
* Create program with objectives "FinancePlan.." "Payroll System" - setup

NavigatePlan
------------

Story #11402 (refactor plan design/layout for consistent UI (across the app)), Story #11409 (refactor plan design/layout for consistent UI (specific pages))
Story #11447 (Make plan and objective URLs meaningful  )

* Add full team member "bob" to program "FinancePlan.."


* Login as "admin"
* Open plan "This plan does not exist" via url
* Assert that cannot access the requested resource
* Open plan "FinancePlan.." in days view
* Click profile link for current user
* Assert current page is profile page for "admin"
* Open plan "FinancePlan.." in days view
* Assert "Sign out" link present
* Login as "bob"
* Open plan "FinancePlan.." in days view
* Click profile link for current user
* Assert current page is profile page for "bob"
* Assert "Sign out" link present
* Open plan "FinancePlan.." in days view
* Click mingle logo
* Assert that current page is programs list page
* Assert that programs tab is active
* Click mingle logo
* Assert that current page is programs list page
* Assert that programs tab is active
* Open plan "FinancePlan.." in days view
* Assert that program name "FinancePlan.." is displayed next to mingle logo
* Open "Projects" page
* Assert that tab "Projects" is highlighted
* Open plan "FinancePlan.."
* Assert that tab "Plan" is highlighted
* Click mingle logo
* Assert that current page is programs list page
* Assert that programs tab is active

open plan from URL -  bug #11327 <mingle>/plans doesn't show the projects/plans tab - just a list of the plans
* Navigate to programs list page
* Assert that projects programs tab is visible
* Assert that programs tab is active
* Assert that program "FinancePlan.." is displayed on programs list

Check plan page is selected by default
* Login as "admin"
* Create program "Navigate to plan"
* Navigate to program "Navigate to plan" plan page
* Assert that tab "Plan" is highlighted



___

Teardown of contexts
* Create program with objectives "FinancePlan.." "Payroll System" - teardown


