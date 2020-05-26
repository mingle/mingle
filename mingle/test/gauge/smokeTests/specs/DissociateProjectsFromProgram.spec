DissociateProjectsFromProgram
=============================

tags: #11261, plan_projects_page, plan_events_page, group_a

Setup of contexts
* Login to mingle as "admin" - setup
* Create program with objectives "Finance Program" "Payroll System" - setup
* Create projects "SAP, Java" with "2" cards - setup

DissociateProjectsFromProgram
-----------------------------


Main business workflow ability to remove project from program
* Associate projects "SAP, Java" with program "Finance Program"
* Navigate to plan "Finance Program" objective "Payroll System" assign work page
* Select project "SAP"
* Select all cards
* Add selected cards to objective
* Navigate to program "Finance Program" projects page
* Remove project "SAP"
* Assert text present "Removing this project will also remove 2 work items from the following objective: Payroll System"
* Click cancel button
* Remove project "Java"
* Assert text present "There is no work from this project."
* Click remove button
* Assert text present "Project Java has been removed from this program."



___

Teardown of contexts
* Create projects "SAP, Java" with "2" cards - teardown
* Create program with objectives "Finance Program" "Payroll System" - teardown
* Login to mingle as "admin" - teardown


