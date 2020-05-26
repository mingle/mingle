WeeksView
=========

tags: weekly, plan, view, timeline_page, New Item, #11222

Setup of contexts
* Login to mingle as "admin" - setup

WeeksView
---------

Story #11222: View plan time line at weekly level

Create objectives on Days view and verfiy them on Weeks view
* Create program "Finance's Plan" with plan from "14 Mar 2011" to "1 May 2011" and switch to days view
* Create objective "Payroll System" starts on "14 Mar 2011" and ends on "15 Mar 2011" in days view
* Create objective "Billing System" starts on "14 Mar 2011" and ends on "16 Mar 2011" in days view
* Create objective "Accounting" starts on "14 Mar 2011" and ends on "20 Mar 2011" in days view
* Create objective "Money" starts on "15 Mar 2011" and ends on "22 Mar 2011" in days view
* Switch to "weeks" view
* Assert that objective "Payroll System" is within the week of "14 Mar 2011"
* Assert that objective "Billing System" is within the week of "14 Mar 2011"
* Assert that objective "Billing System" is longer than objective "Payroll System"
* Assert that objective "Accounting" only spans entire week of "14 Mar 2011"
* Assert that objective "Money" cross weeks that begins from "14 Mar 2011" and week begins from "21 Mar 2011"

Create objective on Weeks view and verify them on Days view
* Create objective "New week" starts on the week begins from "14 Mar 2011" and ends on the week begins from "28 Mar 2011" in weeks view
* Assert that objective "New week" cross weeks that begins from "14 Mar 2011" and week begins from "28 Mar 2011"
* Switch to "days" view
* Assert that objective "New week" starts on "14 Mar 2011" and ends on "3 Apr 2011" in days view
* Switch to "weeks" view
* Drag the end date of objective "New week" to day "1" of the week begins from "28 Mar 2011"
* Switch to "days" view
* Assert that objective "New week" starts on "14 Mar 2011" and ends on "28 Mar 2011" in days view
* Switch to "weeks" view
* Drag the end date of objective "New week" to day "1" of the week begins from "14 Mar 2011"
* Switch to "days" view
* Assert that objective "New week" starts on "14 Mar 2011" and ends on "14 Mar 2011" in days view

Drag the left handle of one objective on Weeks view to modify its start date
* Switch to "weeks" view
* Create objective "Another week" starts on the week begins from "14 Mar 2011" and ends on the week begins from "28 Mar 2011" in weeks view
* Drag the start date of objective "Another week" to day "4" of the week begins from "14 Mar 2011"
* Switch to "days" view
* Assert that objective "Another week" starts on "18 Mar 2011" and ends on "3 Apr 2011" in days view

Drag and drop the objective on Weeksview
* Switch to "weeks" view
* Move objective "Another week" to start on the day "2" of the week begin from "28 Mar 2011"
* Switch to "days" view
* Assert that objective "Another week" starts on "30 Mar 2011" and ends on "15 Apr 2011" in days view
* Switch to "months" view
* Assert that objective "Another week" starts on "30 Mar 2011" and ends on "15 Apr 2011" in months view


___

Teardown of contexts
* Login to mingle as "admin" - teardown


