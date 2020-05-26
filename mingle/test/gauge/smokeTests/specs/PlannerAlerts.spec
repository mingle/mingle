PlannerAlerts
=============

tags: group_a

Setup of contexts
* FakeNow "2011" "02" "20" - setup
* Login to mingle as "admin" - setup
* Create projects "SAP,Java" with "4" cards - setup

PlannerAlerts
-------------

	Create a Plan and a Objective
* Create program "Finance Program" with plan from "10 Feb 2011" to "1 Apr 2011" and switch to days view
* Create objective "Payroll System" starts on "20 Feb 2011" and ends on "13 Mar 2011" in days view

Add properties in project
* Create managed text property "Status" in project "SAP" with values "Open, In Progress, QA Complete"

Associate projects with plan
* Open plan "Finance Program"
* Open "Projects" page
* Associate projects "SAP" with program
* Associate projects "Java" with program

Map status to objective
* Open define done status page of project "SAP"
* Map property "Status" value "QA Complete" to plan done status

Add work to objective
* Open plan "Finance Program"
* Click on addWork in the objective "Payroll System"
* Select project "SAP"
* Set filter number "0" with property "Type" operator "is" and value "Card" on add work page
* Add another filter
* Set filter number "1" with property "Status" operator "is not" and value "QA Complete" on add work page
* Select cards "SAP_1, SAP_2,SAP_3,SAP_4"
* Add selected cards to objective
* Select project "Java"
* Set filter number "0" with property "Type" operator "is" and value "Card" on add work page
* Select cards "Java_1, Java_2,Java_3,Java_4"
* Add selected cards to objective

Complete work items on SAP project
* Bulk update "Status" of cards number "SAP_1" of project "SAP" from "(not set)" to "QA Complete"
* Fake date "2011" "02" "21" and login to mingle as "admin"
* Bulk update "Status" of cards number "SAP_2" of project "SAP" from "(not set)" to "QA Complete"
* Get planner forecasting info for objective "Payroll System" and project "SAP"


Verify Alerts are displayed (10 % time passed but no work item completed)
* Fake date "2011" "02" "22" and login to mingle as "admin"
* Open plan "Finance Program"
* Switch to "months" view
* Verify alert is not displayed in "Payroll System" objective
* Drag objective "Payroll System" from end date "13 Mar 2011" to "11 Mar 2011" in months view
* Verify alert is displayed in "Payroll System" objective


Remove project Java from plan
* Open plan "Finance Program"
* Open "Projects" page
* Remove project "Java"
* Click remove button


Verify Alerts are displayed For SAP project when work is not completed before forecasted time
* Open plan "Finance Program"
* Switch to "months" view
* Drag objective "Payroll System" from end date "11 Mar 2011" to "26 Feb 2011" in months view
* Verify alert is not displayed in "Payroll System" objective
* Drag objective "Payroll System" from end date "26 Feb 2011" to "25 Feb 2011" in months view
* Verify alert is displayed in "Payroll System" objective
* Open objective "Payroll System" popup
* Verify alert is displayed for "SAP" project


After completing all work even after the forcasted dates no alert should be displayed
* Fake date "2011" "03" "4" and login to mingle as "admin"
* Bulk update "Status" of cards number "SAP_3,SAP_4" of project "SAP" from "(not set)" to "QA Complete"
* Get planner forecasting info and login to mingle as "admin"
* Open plan "Finance Program"
* Switch to "months" view
* Verify alert is not displayed in "Payroll System" objective
* Open objective "Payroll System" popup
* Open project forecasting chart for "SAP"
* Assert work items completed is "4" of "4"


___

Teardown of contexts
* Create projects "SAP,Java" with "4" cards - teardown
* Login to mingle as "admin" - teardown
* FakeNow "2011" "02" "20" - teardown


