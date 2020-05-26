MonthsView
==========

tags: #11493, group_a

MonthsView
----------

Story #11493 (View plan timeline at monthly level)


1. User can create a objective on the timeline
* Login as "admin"
* Create program "Finance Program" with plan from "11 Jan 2010" to "1 Jan 2011" and switch to days view
* Open plan "Finance Program" in days view
* Open "Plan" page
* Switch to "months" view
* Create objective "Business License System" starts on "10 Jan 2010" and ends on "12 Feb 2010" in months view
* Drag objective "Business License System" from end date "12 Feb 2010" to "5 Feb 2010" in months view

2 User can move a objective
* Open "Plan" page
* Switch to "months" view
* Create objective "Payable System" starts on "10 Jan 2010" and ends on "20 Jan 2010" in months view
* Move objective "Payable System" from "10 Jan 2010" to start on "5 Jan 2010" in months view
* Refresh plan page
* Assert that objective "Payable System" starts on "5 Jan 2010" and ends on "15 Jan 2010" in months view

3. User can drag the objective start date
* Open "Plan" page
* Switch to "months" view
* Create objective "Receivable System" starts on "10 Jan 2010" and ends on "20 Jan 2010" in months view
* Drag the "start date" of objective "Receivable System" to day "5" of the month begins from "1 Jan 2010"
* Refresh plan page
* Assert that objective "Receivable System" starts on "5 Jan 2010" and ends on "20 Jan 2010" in months view

4. User can drag the objective end date
* Open "Plan" page
* Switch to "months" view
* Create objective "A New Feature" starts on "10 Jan 2010" and ends on "20 Jan 2010" in months view
* Drag the "end date" of objective "A New Feature" to day "25" of the month begins from "1 Feb 2010"
* Refresh plan page
* Assert that objective "A New Feature" starts on "10 Jan 2010" and ends on "25 Feb 2010" in months view

5. When plan starts after the first day of the month, show the entire first month
* Open "Plan" page
* Switch to "months" view
* Assert that the first month on timeline page is "December 2009"

6. When a objective is created before the plan start date, the plan start date moves further back
* Switch to "months" view
* Create objective "Billing System" starts on "6 Jan 2010" and ends on "16 Jan 2010" in months view
* Switch to "weeks" view
* Assert that the first week on timeline page is "28 Dec 2009 - 3 Jan 2010"
* Assert that objective "Billing System" starts on "6 Jan 2010" and ends on "16 Jan 2010" in weeks view


When a objective is created that moves the plan back a month, that month is displayed in months view when we return to months view
* Switch to "months" view
* Create objective "Accounting System" starts on "1 Jan 2010" and ends on "10 Jan 2010" in months view
* Switch to "weeks" view
* Assert that the first week on timeline page is "30 Nov 2009 - 6 Dec 2009"
* Switch to "months" view
* Assert that the first month on timeline page is "November 2009"

When plan ends before the last day of the month, show the entire last month
* Switch to "months" view
* Scroll to the end of the plan
* Assert that the last month on timeline page is "January 2011"

When a objective is created that moves the plan forward a month, that month is displayed in months view when we return to months view
* Switch to "months" view
* Scroll to the end of the plan
* Create objective "Human Resources System" starts on "21 Jan 2011" and ends on "31 Jan 2011" in months view
* Switch to "weeks" view
* Assert that the last week on timeline page is "31 Jan 2011 - 6 Feb 2011"
* Switch to "months" view
* Assert that the last month on timeline page is "February 2011"

When user creates a objective in days view, it is shown on months view
* Open "Plan" page
* Switch to "days" view
* Create objective "Jay System" starts on "21 Feb 2010" and ends on "28 Feb 2010" in days view
* Open "Plan" page
* Switch to "months" view
* Assert that objective "Jay System" starts on "21 Feb 2010" and ends on "28 Feb 2010" in months view


