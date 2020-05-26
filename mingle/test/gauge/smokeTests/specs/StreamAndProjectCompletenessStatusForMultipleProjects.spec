StreamAndProjectCompletenessStatusForMultipleProjects
=====================================================

tags: #13148, #12990

Setup of contexts
* Login to mingle as "admin" - setup
* Create projects "SAP,Java" with "10" cards - setup
* Create program with objectives "Finance Program" "Payroll System, Billing System" - setup

StreamAndProjectCompletenessStatusForMultipleProjects
-----------------------------------------------------

When there is work associated to the objective is from multiple projects and few of them are completed appropriate details should show in the view

Add properties in project
* Create managed text property "Status" in project "SAP" with values "Open, In Progress, QA Complete"
* Create managed text property "Status" in project "Java" with values "Open, In Progress, Done"

Associate projects with plan
* Open plan "Finance Program" in days view
* Open "Projects" page
* Associate projects "SAP,Java" with program

Map status to objective
* Open define done status page of project "SAP"
* Map property "Status" value "QA Complete" to plan done status
* Open define done status page of project "Java"
* Map property "Status" value "Done" to plan done status

Add work to objective
* Open plan "Finance Program"
* Click on addWork in the objective "Billing System"
* Select project "SAP"
* Set filter number "0" with property "Type" operator "is" and value "Card" on add work page
* Add another filter
* Set filter number "1" with property "Status" operator "is not" and value "QA Complete" on add work page
* Select cards "SAP_6, SAP_7,SAP_8,SAP_9,SAP_10"
* Add selected cards to objective
* Select project "Java"
* Set filter number "0" with property "Type" operator "is" and value "Card" on add work page
* Add another filter
* Set filter number "1" with property "Status" operator "is not" and value "Done" on add work page
* Select cards "Java_1, Java_2,Java_3,Java_4,Java_5"
* Add selected cards to objective

Verify Objective and Project Completeness for a multiple project
* Open plan "Finance Program"
* Assert the number of work items completed in objective "Billing System" is "0" of "10"
* Open objective "Billing System" popup
* Assert "SAP,Java" project is present in the objective popup
* Assert the number of work items completed in project "SAP" is "0" of "5"
* Assert the progress of the project "SAP" when "0" of "5" items are completed
* Assert the number of work items completed in project "Java" is "0" of "5"
* Assert the progress of the project "Java" when "0" of "5" items are completed
* Bulk update "Status" of cards number "SAP_6, SAP_7,SAP_8" of project "SAP" from "(not set)" to "QA Complete"
* Bulk update "Status" of cards number "Java_1, Java_2,Java_3,Java_4" of project "Java" from "(not set)" to "Done"
* Open plan "Finance Program" in days view
* Assert the number of work items completed in objective "Billing System" is "7" of "10"
* Open objective "Billing System" popup
* Assert the number of work items completed in project "SAP" is "3" of "5"
* Assert the progress of the project "SAP" when "3" of "5" items are completed
* Assert the number of work items completed in project "Java" is "4" of "5"
* Assert the progress of the project "Java" when "4" of "5" items are completed
* Bulk update "Status" of cards number "SAP_9, SAP_10" of project "SAP" from "(not set)" to "QA Complete"
* Bulk update "Status" of cards number "Java_5" of project "Java" from "(not set)" to "Done"
* Open plan "Finance Program" in days view
* Assert the number of work items completed in objective "Billing System" is "10" of "10"
* Open objective "Billing System" popup
* Assert the number of work items completed in project "SAP" is "5" of "5"
* Assert the progress of the project "SAP" when "5" of "5" items are completed
* Assert the number of work items completed in project "Java" is "5" of "5"
* Assert the progress of the project "Java" when "5" of "5" items are completed


___

Teardown of contexts
* Create program with objectives "Finance Program" "Payroll System, Billing System" - teardown
* Create projects "SAP,Java" with "10" cards - teardown
* Login to mingle as "admin" - teardown


