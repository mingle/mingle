PlanWorkList
============

tags: add_remove_work

Setup of contexts
* Login to mingle as "admin" - setup
* Create projects "SAP, Java" with cards - setup
* Create program with objectives "Finance Program" "Payroll System, Billing System" - setup
* Associate projects "Java, SAP" with program "Finance Program" - setup

PlanWorkList
------------

Add cards from mutliple projects to different objectives
* Navigate to plan "Finance Program" objective "Payroll System" assign work page
* Add cards "SAP_1" from "SAP" project to current objective
* Add cards "Java_2,Java_3" from "Java" project to current objective
* Navigate to plan "Finance Program" objective "Billing System" assign work page
* Add cards "SAP_2, SAP_3" from "SAP" project to current objective
* Add cards "Java_1" from "Java" project to current objective

Ability to use filter on work page
* View all work for "Payroll System" objective
* Add another filter in work
* Set filter number "0" with property "Project" operator "is" and value "SAP" on work page
* Assert that cards "SAP_1" of project "SAP" are present in work table
* View all work for "Billing System" objective
* Assert that cards "SAP_2, SAP_3" of project "SAP" are present in work table
* View all work for "Payroll System" objective
* Assert that cards "SAP_1" of project "SAP" are present in work table

Data setup for filter status test below
* Create managed text property "Status" in project "Java" with values "Open, Closed"
* Create hidden managed text property "Hidden Property" in project "SAP" with values "Hidden2,Hidden"
* Navigate to program "Finance Program" projects page
* Open define done status page of project "SAP"
* Map property "Hidden Property" value "Hidden" to plan done status
* Navigate to program "Finance Program" projects page
* Open define done status page of project "Java"
* Map property "Status" value "Closed" to plan done status
* Set "Status" in card number "1" of project "Java" to "Closed"
* Set "Status" in card number "2" of project "Java" to "Open"
* Set "Hidden Property" in card number "1" of project "SAP" to "Hidden"
* Set "Hidden Property" in card number "2" of project "SAP" to "Hidden2"

Bug #12033 done status is not updated correctly when adding cards to objective before mapping project's done status
* View all work for "Billing System" objective
* Assert that the status column for cards "Java_1" is "Done"
* Assert that the status column for cards "SAP_3" is "Not done"
* Assert that the status column for cards "SAP_2" is "Not done"
* View all work for "Payroll System" objective
* Assert that the status column for cards "SAP_1" is "Done"

Using filter with status property on Work Page.
* View all work for "Payroll System" objective
* Add another filter in work
* Set filter number "0" with property "Project" operator "is" and value "SAP" on work page
* Add another filter in work
* Set filter number "1" with property "Status" operator "is" and value "Done" on work page
* Assert that cards "SAP_1" of project "SAP" are present in work table
* Set filter number "0" with property "Project" operator "is" and value "(any)" on work page
* Assert that cards "SAP_1" of project "SAP" are present in work table
* View all work for "Billing System" objective
* Add another filter in work
* Set filter number "0" with property "Status" operator "is" and value "Done" on work page
* Assert that cards "Java_1" of project "Java" are present in work table

View and access work from objective popup on timeline
* Open plan "Finance Program"
* Switch to "months" view
* Open objective "Billing System" popup
* View work of the "Billing System" in plan "Finance Program"
* Assert that cards "SAP_2,SAP_3" of project "SAP" are present in work table

___

Teardown of contexts
* Associate projects "Java, SAP" with program "Finance Program" - teardown
* Create program with objectives "Finance Program" "Payroll System, Billing System" - teardown
* Create projects "SAP, Java" with cards - teardown
* Login to mingle as "admin" - teardown


