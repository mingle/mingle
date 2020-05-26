ViewWorkPage
============
tags: add_remove_work

Setup of contexts
* Login to mingle as "admin" - setup
* Create projects "SAP, Java" with cards - setup
* Create program with objectives "Finance Program" "Payroll System" - setup

ViewWorkPage
------------

Add properties in project
* Create managed text property "Status" in project "SAP" with values "Open, In Progress, QA Complete"
* Create managed text property "Status" in project "Java" with values "Open, In Progress, QA Complete"

Associate projects with program
* Open plan "Finance Program" in days view
* Open "Projects" page
* Associate projects "SAP,Java" with program

Map status to objective
* Open define done status page of project "SAP"
* Map property "Status" value "QA Complete" to plan done status


Add work to objective
* Open plan "Finance Program"
* Switch to "months" view
* Click on addWork in the objective "Payroll System"
* Add cards "SAP_1, SAP_2" from "SAP" project to current objective
* Add cards "Java_1, Java_2" from "Java" project to current objective


View work on a objective when no work items complete
* Open plan "Finance Program"
* Click on viewWork in the objective "Payroll System"
* Assert work not done filter set for objective "payroll System" for property "Status"
* Assert that cards "SAP_1, SAP_2, Java_2, Java_1" are present in view work table
* Assert "\"Done\" status not defined for project" link is present for "Java_1, Java_2"
* Assert "Java,SAP" link present
* Assert link url of "Java" is "/projects/java"
* Assert link url of "SAP" is "/projects/sap"
* Click on "\"Done\" status not defined for project" link for card "Java_1"
* Map property "Status" value "QA Complete" to plan done status
* Bulk update "Status" of cards number "SAP_2, SAP_1" of project "SAP" from "(not set)" to "QA Complete"
* Bulk update "Status" of cards number "Java_2, Java_1" of project "Java" from "(not set)" to "QA Complete"
* Open plan "Finance Program" in days view
* Switch to "months" view
* Click on viewWork in the objective "Payroll System"
* Assert no work items in view work page

___

Teardown of contexts
* Create program with objectives "Finance Program" "Payroll System" - teardown
* Create projects "SAP, Java" with cards - teardown
* Login to mingle as "admin" - teardown


