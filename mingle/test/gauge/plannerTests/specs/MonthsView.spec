MonthsView
==========
tags: planner_views

MonthsView
----------

Story #11493 (View plan timeline at monthly level)


1. User can create a objective on the timeline
* Login as "admin"
* Create program "Finance Program" with plan from "11 Jan 2010" to "1 Jan 2011" and switch to days view
* Create objective "Business License System" on "Finance Program" starts on "10 Jan 2010" and ends on "12 Feb 2010" in months view
* Open plan "Finance Program" in days view
* Open "Plan" page
* Switch to "months" view
* Drag objective "Business License System" from end date "12 Feb 2010" to "5 Feb 2010" in months view
* Delete objective "Business License System" of plan "Finance Program"

2 User can move a objective
* Create objective "Payable System" on "Finance Program" starts on "10 Jan 2010" and ends on "20 Jan 2010" in months view
* Open "Plan" page
* Switch to "months" view
* Move objective "Payable System" from "10 Jan 2010" to start on "5 Jan 2010" in months view
* Reload the page from server
* Assert that objective "Payable System" starts on "5 Jan 2010" and ends on "20 Jan 2010" in months view
* Delete objective "Payable System" of plan "Finance Program"

3. User can drag the objective start date
* Create objective "Receivable System" on "Finance Program" starts on "10 Jan 2010" and ends on "20 Jan 2010" in months view
* Open "Plan" page
* Switch to "months" view
* Drag the "start date" of objective "Receivable System" to day "5" of the month to "left" begins from "1 Jan 2010"
* Reload the page from server
* Assert that objective "Receivable System" starts on "5 Jan 2010" and ends on "20 Jan 2010" in months view
* Delete objective "Receivable System" of plan "Finance Program"

4. User can drag the objective end date
* Create objective "A New Feature" on "Finance Program" starts on "10 Jan 2010" and ends on "20 Jan 2010" in months view
* Open "Plan" page
* Switch to "months" view
* Drag the "end date" of objective "A New Feature" to day "25" of the month to "right" begins from "1 Feb 2010"
* Reload the page from server
* Assert that objective "A New Feature" starts on "10 Jan 2010" and ends on "25 Feb 2010" in months view
* Delete objective "A New Feature" of plan "Finance Program"

5. When plan starts after the first day of the month, show the entire first month
* Open "Plan" page
* Switch to "months" view
* Assert that the first month on timeline page is "January 2010"

6. When a objective is created before the plan start date, the plan start date moves further back
* Switch to "months" view
* Create objective "Billing System" on "Finance Program" starts on "6 Jan 2010" and ends on "16 Jan 2010" in months view
* Switch to "weeks" view
* Assert that the first week on timeline page is "4 Jan 2010 - 10 Jan 2010"
* Assert that objective "Billing System" starts on "6 Jan 2010" and ends on "16 Jan 2010" in weeks view
* Delete objective "Billing System" of plan "Finance Program"


When a objective is created that moves the plan back a month, that month is displayed in months view when we return to months view
* Switch to "months" view
* Create objective "Accounting System" on "Finance Program" starts on "1 Jan 2010" and ends on "10 Jan 2010" in months view
* Switch to "weeks" view
* Assert that the first week on timeline page is "28 Dec 2009 - 3 Jan 2010"
* Switch to "months" view
* Assert that the first month on timeline page is "December 2009"
* Delete objective "Accounting System" of plan "Finance Program"

When plan ends before the last day of the month, show the entire last month
* Switch to "months" view
* Scroll to the end of the plan
* Assert that the last month on timeline page is "January 2011"

When a objective is created that moves the plan forward a month, that month is displayed in months view when we return to months view
* Switch to "months" view
* Scroll to the end of the plan
* Create objective "Human Resources System" on "Finance Program" starts on "21 Jan 2011" and ends on "31 Jan 2011" in months view
* Switch to "weeks" view
* Assert that the last week on timeline page is "31 Jan 2011 - 6 Feb 2011"
* Switch to "months" view
* Assert that the last month on timeline page is "February 2011"

When user creates a objective in days view, it is shown on months view
* Open "Plan" page
* Switch to "days" view
* Create objective "Jay System" on "Finance Program" starts on "21 Feb 2010" and ends on "28 Feb 2010" in days view
* Open "Plan" page
* Switch to "months" view
* Assert that objective "Jay System" starts on "21 Feb 2010" and ends on "28 Feb 2010" in months view


