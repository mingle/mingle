PlannerForecastingWhenReorderingDoneStatus
==========================================

tags: planner_forecast

Setup of contexts
* FakeNow "2011" "2" "19" - setup
* Login to mingle as "admin" - setup
* Create projects "SAP" with "10" cards - setup

PlannerForecastingWhenReorderingDoneStatus
------------------------------------------

Create a Plan and a Objective
* Create program "Finance Program" with plan from "10 Feb 2011" to "1 Apr 2011" and switch to days view
* Create objective "Payroll System" on "Finance Program" starts on "20 Feb 2011" and ends on "25 Feb 2011" in days view

Add properties in project
* Create managed text property "Status" in project "SAP" with values "Open, In Progress, QA Complete,Customer Ready"
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
* Switch to "months" view
* Open objective "Payroll System" popup
* Click addWork link
* Select project "SAP"
* Set filter number "0" with property "Type" operator "is" and value "Card" on add work page
* Add another filter
* Set filter number "1" with property "Status" operator "is not" and value "QA Complete" on add work page
* Select cards "SAP_1, SAP_2,SAP_3,SAP_4,SAP_5,SAP_6"
* Add selected cards to objective


Verify Forecasting information when work items are completed
* Bulk update "Status" of cards number "SAP_5" of project "SAP" from "(not set)" to "Customer Ready"
* Fake date "2011" "02" "20" and login to mingle as "admin"
* Bulk update "Status" of cards number "SAP_1,SAP_2" of project "SAP" from "(not set)" to "QA Complete"
* Fake date "2011" "02" "21" and login to mingle as "admin"
* Bulk update "Status" of cards number "SAP_3,SAP_4" of project "SAP" from "(not set)" to "QA Complete"
* Fake date "2011" "02" "22" and login to mingle as "admin"
* Get planner forecasting info for objective "Payroll System" and project "SAP"
* Open plan "Finance Program" in days view
* Switch to "months" view
* Open objective "Payroll System" popup
* Open project forecasting chart for "SAP"
* Assert work items completed is "5" of "6"
* Assert date of completion 0 percent is "23 Feb 2011" 50 percent is "23 Feb 2011" and 150 percent is "24 Feb 2011"


Reorder status(Move Customer ready above QA complete)
* Navigate to project "SAP" property definitions page
* Open enumerated values page of property "Status" using link "4 values"
* Drag "Customer Ready" upwards above "QA Complete"
* Get planner forecasting info for objective "Payroll System" and project "SAP"
* Open plan "Finance Program" in days view
* Switch to "months" view
* Open objective "Payroll System" popup
* Open project forecasting chart for "SAP"
* Assert work items completed is "4" of "6"
* Assert date of completion 0 percent is "24 Feb 2011" 50 percent is "25 Feb 2011" and 150 percent is "27 Feb 2011"

___

Teardown of contexts
* Create projects "SAP" with "10" cards - teardown
* Login to mingle as "admin" - teardown
* FakeNow "2011" "2" "19" - teardown


