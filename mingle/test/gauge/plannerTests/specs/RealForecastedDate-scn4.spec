RealForecastedDate-scn4
=======================

tags: planner_forecast

Setup of contexts
* Login to mingle as "admin" - setup
* FakeNow "2010" "12" "31" - setup
* Create projects "SAP" with "12" cards - setup

RealForecastedDate-scn4
-----------------------

Create a plan and objective and associate with a project
* Create program "Finance Program" with plan from "25 Dec 2010" to "1 Apr 2012" and switch to days view
* Create objective "Payroll System" on "Finance Program" starts on "31 Dec 2010" and ends on "15 Jan 2011" in days view
* Open plan "Finance Program" in days view
* Switch to "months" view
* Open "Projects" page
* Associate projects "SAP" with program


Add work to objective
* Open plan "Finance Program" in days view
* Switch to "months" view
* Click on addWork in the objective "Payroll System"
* Select project "SAP"
* Set filter number "0" with property "Type" operator "is" and value "Card" on add work page
* Select all cards
* Deselect cards "SAP_2"
* Add selected cards to objective

Add properties in project
* Create managed text property "Status" in project "SAP" with values "Open, In Progress, QA Complete, Closed"

Map status to objective
* Open plan "Finance Program" in days view
* Switch to "months" view
* Open "Projects" page
* Open define done status page of project "SAP"
* Map property "Status" value "QA Complete" to plan done status

Comple work items in project
* Fake date "2011" "01" "01" and login to mingle as "admin"
* Bulk update "Status" of cards number "SAP_1" of project "SAP" from "(not set)" to "QA Complete"
* Fake date "2011" "01" "02" and login to mingle as "admin"
* Bulk update "Status" of cards number "SAP_2" of project "SAP" from "(not set)" to "QA Complete"
* Fake date "2011" "01" "03" and login to mingle as "admin"
* Bulk update "Status" of cards number "SAP_3" of project "SAP" from "(not set)" to "QA Complete"
* Fake date "2011" "01" "04" and login to mingle as "admin"
* Bulk update "Status" of cards number "SAP_4" of project "SAP" from "(not set)" to "QA Complete"

Add work to objective
* Open plan "Finance Program" in days view
* Switch to "months" view
* Click on addWork in the objective "Payroll System" -forcast
* Select project "SAP"
* Set filter number "0" with property "Type" operator "is" and value "Card" on add work page
* Select cards "SAP_2"
* Add selected cards to objective

Comple more work items in project
* Fake date "2011" "01" "05" and login to mingle as "admin"
* Bulk update "Status" of cards number "SAP_5" of project "SAP" from "(not set)" to "QA Complete"
* Fake date "2011" "01" "06" and login to mingle as "admin"
* Bulk update "Status" of cards number "SAP_6" of project "SAP" from "(not set)" to "QA Complete"

Get forecast chart
* Fake date "2011" "01" "06" and login to mingle as "admin"
* Get planner forecasting info for objective "Payroll System" and project "SAP"
* Open forcasting chart for project "SAP" for objective "Payroll System" in "Finance Program"
* Assert date of completion 0 percent is "12 Jan 2011" 50 percent is "15 Jan 2011" and 150 percent is "21 Jan 2011"


___

Teardown of contexts
* Create projects "SAP" with "12" cards - teardown
* FakeNow "2010" "12" "31" - teardown
* Login to mingle as "admin" - teardown


