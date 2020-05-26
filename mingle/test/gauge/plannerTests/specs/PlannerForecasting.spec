PlannerForecasting
==================

tags: flacky_test

Setup of contexts
* FakeNow "2011" "02" "19" - setup
* Login to mingle as "admin" - setup
* Create projects "SAP" with "12" cards - setup

PlannerForecasting
------------------

Create a Plan and a Objective
* Create program "Finance Program" with plan from "10 Feb 2011" to "1 Apr 2011" and switch to days view
* Create objective "Payroll System" on "Finance Program" starts on "20 Feb 2011" and ends on "25 Feb 2011" in days view

Add properties in project
* Create managed text property "Status" in project "SAP" with values "Open, In Progress, QA Complete"

Associate projects with plan
* Open plan "Finance Program" in days view
* Switch to "months" view
* Open objective "Payroll System" popup
* Assert links not present in objective popup "Add work, View work"
* Click "Add projects" link
* Associate projects "SAP" with program

Map status to objective
* Open define done status page of project "SAP"
* Map property "Status" value "QA Complete" to plan done status

Add work to objective
* Open plan "Finance Program"
* Open objective "Payroll System" popup
* Assert links not present in objective popup "View work"
* Click addWork link
* Select project "SAP"
* Set filter number "0" with property "Type" operator "is" and value "Card" on add work page
* Add another filter
* Set filter number "1" with property "Status" operator "is not" and value "QA Complete" on add work page
* Select cards "SAP_1, SAP_2,SAP_3,SAP_4,SAP_5,SAP_6,SAP_11"
* Add selected cards to objective


Verify Forecasting information when work items are completed
* Bulk update "Status" of cards number "SAP_11" of project "SAP" from "(not set)" to "In Progress"
* Fake date "2011" "02" "20" and login to mingle as "admin"
* Bulk update "Status" of cards number "SAP_1,SAP_2" of project "SAP" from "(not set)" to "QA Complete"
* Fake date "2011" "02" "21" and login to mingle as "admin"
* Bulk update "Status" of cards number "SAP_3,SAP_4" of project "SAP" from "(not set)" to "QA Complete"
* Fake date "2011" "02" "22" and login to mingle as "admin"
* Get planner forecasting info for objective "Payroll System" and project "SAP"
* Open plan "Finance Program" in days view
* Switch to "months" view
 Verify alert is not displayed in "Payroll System" objective
* Open objective "Payroll System" popup
* Open project forecasting chart for "SAP"
* Assert date of completion 0 percent is "25 Feb 2011" 50 percent is "26 Feb 2011" and 150 percent is "1 Mar 2011"
* Close the ForcastPopup

Verify Forecasting information when scope increases
* Navigate to objective "Payroll System" of plan "Finance Program"
* Open add works page
* Select project "SAP"
* Set filter number "0" with property "Type" operator "is" and value "Card" on add work page
* Add another filter
* Set filter number "1" with property "Status" operator "is not" and value "QA Complete" on add work page
* Select cards "SAP_7,SAP_8"
* Add selected cards to objective
* Get planner forecasting info for objective "Payroll System" and project "SAP"
* Open plan "Finance Program" in days view
* Switch to "months" view
* Verify alert is displayed in "Payroll System" objective
* Open objective "Payroll System" popup
* Open project forecasting chart for "SAP"
* Assert date of completion 0 percent is "27 Feb 2011" 50 percent is "1 Mar 2011" and 150 percent is "6 Mar 2011"
* Close the ForcastPopup

Verify Forecasting information when scope decreases
* View all work for "Payroll System" objective
* Select cards "7, 8" from project "SAP" on work page
* Remove selected work items from objective
* Assert text present "2 work items removed from the feature Payroll System"
* Get planner forecasting info for objective "Payroll System" and project "SAP"
* Open plan "Finance Program" in days view
* Switch to "months" view
* Verify alert is not displayed in "Payroll System" objective
* Open objective "Payroll System" popup
* Open project forecasting chart for "SAP"
* Assert title of forecast chart "Payroll System" "SAP"
* Assert work items completed is "4" of "7"
* Assert date of completion 0 percent is "25 Feb 2011" 50 percent is "26 Feb 2011" and 150 percent is "1 Mar 2011"

verify change in define done status value reflect the chart
* Navigate to objective "Payroll System" of plan "Finance Program"
* Open add works page
* Add cards "SAP_9, SAP_10" from "SAP" project to current objective
* Fake date "2011" "02" "23" and login to mingle as "admin"
* Bulk update "Status" of cards number "SAP_6" of project "SAP" from "(not set)" to "In Progress"
* Open plan "Finance Program" in days view
* Open "Projects" page
* Edit done status from "QA Complete" for project "SAP"
* Map property "Status" value "In Progress" to plan done status
* Get planner forecasting info for objective "Payroll System" and project "SAP"
* Open plan "Finance Program" in days view
* Switch to "months" view
* Open objective "Payroll System" popup
* Open project forecasting chart for "SAP"
* Assert work items completed is "6" of "9"
* Assert date of completion 0 percent is "26 Feb 2011" 50 percent is "28 Feb 2011" and 150 percent is "3 Mar 2011"
* Close the ForcastPopup
* Open "Projects" page
* Edit done status from "In Progress" for project "SAP"
* Map property "Status" value "QA Complete" to plan done status
* Get planner forecasting info for objective "Payroll System" and project "SAP"
* Open plan "Finance Program" in days view
* Switch to "months" view
* Open objective "Payroll System" popup
* Open project forecasting chart for "SAP"
* Assert work items completed is "4" of "9"
* Assert date of completion 0 percent is "3 Mar 2011" 50 percent is "7 Mar 2011" and 150 percent is "15 Mar 2011"

Recalculate velocity on changing objective start date
* Open plan "Finance Program" in days view
* Switch to "weeks" view
* Drag objective "Payroll System" from start date "20 Feb 2011" to "19 Feb 2011" in months view
* Get planner forecasting info for objective "Payroll System" and project "SAP"
* Open forcasting chart for project "SAP" for objective "Payroll System" in "Finance Program"
* Assert work items completed is "4" of "9"
* Assert date of completion 0 percent is "28 Feb 2011" 50 percent is "2 Mar 2011" and 150 percent is "7 Mar 2011"
* Drag objective "Payroll System" from start date "19 Feb 2011" to "16 Feb 2011" in months view
* Get planner forecasting info for objective "Payroll System" and project "SAP"
* Open forcasting chart for project "SAP" for objective "Payroll System" in "Finance Program"
* Assert date of completion 0 percent is "28 Feb 2011" 50 percent is "2 Mar 2011" and 150 percent is "7 Mar 2011"
___

Teardown of contexts
* Create projects "SAP" with "12" cards - teardown
* Login to mingle as "admin" - teardown
* FakeNow "2011" "02" "19" - teardown


