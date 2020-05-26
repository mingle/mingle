DeleteProgram
=============

tags: program_page

Setup of contexts
* Login to mingle as "admin" - setup
* Create projects "SAP, Java" with cards - setup

DeleteProgram
-------------

Should see warning message when deleting a program although it has no objective, no backlog objectives and no associated projects.
* Create program "Finance Program" with plan from "1 Jan 2010" to "10 Feb 2010" and switch to days view
* Navigate to programs list page
* Choose to delete program "Finance Program"
* Assert text present "This program currently has a plan with no planned features and a backlog with no unplanned features. No projects are associated with this program."

Cancel the plan deletion
* Click cancel button
* Navigate to programs list page
* Assert that program "Finance Program" is displayed on programs list

Delete a program which plan is already associated with objective and cards.
* Open plan "Finance Program" in days view
* Create objective "Payroll System" on "Finance Program" starts on "2010-01-06" and ends on "2010-02-04" in days view
* Navigate to program "Finance Program" projects page
* Associate projects "SAP" with program
* Add card "1,2" from project "SAP" to plan "Finance Program" and assign to objective "Payroll System"
* Navigate to programs list page
* Choose to delete program "Finance Program"
* Assert text present "This program currently has a plan with 1 planned feature and a backlog with no unplanned features. 1 project is associated with this program."
* Confirm program deletion
* Assert that program is not displayed on programs list "Finance Program"
* Open card number "1" from project "SAP" to edit
* Assert that the objective "Payroll System" not present on card
___

Teardown of contexts
* Create projects "SAP, Java" with cards - teardown
* Login to mingle as "admin" - teardown


