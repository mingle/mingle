CreateObjective
===============

tags: Plan, #11164, planning mode, plan setup, #11379, #11801, timeline_page, group_a

Setup of contexts
* Login to mingle as "admin" - setup

CreateObjective
---------------

story #11164 (Planner existing functionality)
story #11801 (When timeline is empty, indicate that user can click and drag to create a objective)

This part is for testing plan creation
* Create program "Finance Program" with plan from "30 Dec 2009" to "19 Mar 2010" and switch to days view
* Assert that the plan begins on "28 Dec 2009" and ends on "21 Mar 2010"

The part is for testing objective cancellation on days view and weeks view
* Attempt to create objective named "Billing System" and click cancel
* Assert that no objective on current page
* Switch to "weeks" view
* Attempt to create objective named "Billing System" and click cancel
* Assert that no objective on current page
* Switch to "months" view


This part is for testing create and modify objective
* Create objective "Payroll System" starts on "28 Dec 2009" and ends on "31 Dec 2009" in months view
* Assert that objective "Payroll System" starts on "28 Dec 2009" and ends on "31 Dec 2009" in months view
* Drag objective "Payroll System" from start date "28 Dec 2009" to "29 Dec 2009" in months view
* Drag objective "Payroll System" from end date "31 Dec 2009" to "01 Jan 2010" in months view
* Assert that objective "Payroll System" starts on "29 Dec 2009" and ends on "01 Jan 2010" in months view
* Move objective "Payroll System" from "29 Dec 2009" to start on "28 Dec 2009" in months view
* Assert that objective "Payroll System" starts on "28 Dec 2009" and ends on "31 Dec 2009" in months view
* Create objective "Billing System" starts on "29 Dec 2009" and ends on "01 Jan 2010" in months view
* Create objective "Accounts Receivable" starts on "30 Dec 2009" and ends on "02 Jan 2010" in months view
* Assert that objective "Payroll System" starts on "28 Dec 2009" and ends on "31 Dec 2009" in months view
* Assert that objective "Billing System" starts on "29 Dec 2009" and ends on "01 Jan 2010" in months view
* Assert that objective "Accounts Receivable" starts on "30 Dec 2009" and ends on "02 Jan 2010" in months view


Changing plan start and end date
* Edit plan "Finance Program" with start as "29 Dec 2009" and end date as "01 Jan 2010"
* Assert text present "Start date is later than Feature Payroll System start date of 28 Dec 2009. Please select an earlier date."
* Assert text present "End date is earlier than Feature Accounts Receivable end date of 2 Jan 2010. Please select an later date."
* Edit plan "Finance Program" with start as "27 Dec 2009" and end date as "06 Jan 2010"
* Switch to "days" view
* Assert that the plan begins on "21 Dec 2009" and ends on "10 Jan 2010"



___

Teardown of contexts
* Login to mingle as "admin" - teardown


