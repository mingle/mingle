StreamAndProjectCompletenessStatusForSingleProject
==================================================

tags: plan_projects_page

Setup of contexts
* Login to mingle as "admin" - setup
* Create projects "SAP" with "10" cards - setup
* Create program with objectives "Finance Program" "Payroll System, Billing System" - setup

StreamAndProjectCompletenessStatusForSingleProject
--------------------------------------------------


When there is work associated to the objective is from a single project and few of them are completed appropriate details should show in the view

Add properties in project
* Create managed text property "Status" in project "SAP" with values "Open, In Progress, QA Complete"

Associate projects with program
* Open plan "Finance Program" via url
* Open "Projects" page
* Associate projects "SAP" with program

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
* Select cards "SAP_1, SAP_2,SAP_3,SAP_4,SAP_5"
* Add selected cards to objective

Verify Objective and Project Completeness for a single project
* Open plan "Finance Program"
* Assert the number of work items completed in objective "Payroll System" is "0" of "5"
* Open objective "Payroll System" popup
* Assert "SAP" project is present in the objective popup
* Assert the number of work items completed in project "SAP" is "0" of "5"
* Assert the progress of the project "SAP" when "0" of "5" items are completed
* Bulk update "Status" of cards number "SAP_1, SAP_2,SAP_3" of project "SAP" from "(not set)" to "QA Complete"
* Open plan "Finance Program" in days view
* Assert the number of work items completed in objective "Payroll System" is "3" of "5"
* Open objective "Payroll System" popup
* Assert the number of work items completed in project "SAP" is "3" of "5"
* Assert the progress of the project "SAP" when "3" of "5" items are completed
* Bulk update "Status" of cards number "SAP_4, SAP_5" of project "SAP" from "(not set)" to "QA Complete"
* Open plan "Finance Program" in days view
* Assert the number of work items completed in objective "Payroll System" is "5" of "5"
* Open objective "Payroll System" popup
* Assert the number of work items completed in project "SAP" is "5" of "5"
* Assert the progress of the project "SAP" when "5" of "5" items are completed

Added the below assertion to verify that on dragging the objective end date completed work items info remains

* Open plan "Finance Program" in days view
* Switch to "months" view
* Drag objective "Payroll System" from end date "14 Jan 2011" to "12 Jan 2011" in months view
* Switch to "days" view
* Assert the number of work items completed in objective "Payroll System" is "5" of "5"






___

Teardown of contexts
* Create program with objectives "Finance Program" "Payroll System, Billing System" - teardown
* Create projects "SAP" with "10" cards - teardown
* Login to mingle as "admin" - teardown


