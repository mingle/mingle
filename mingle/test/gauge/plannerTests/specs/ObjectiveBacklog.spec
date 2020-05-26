ObjectiveBacklog
================

tags: objectives

Setup of contexts
* Login to mingle as "admin" - setup
* Create projects "SAP" with "5" cards - setup

ObjectiveBacklog
----------------


Create backlog objectives
* Create program "First Plan" and switch to days view in plan
* Navigate to programs list page
* Click backlog link for the program "First Plan"
* Assert backlog objective name cannot be blank
* Create backlog objective "objective1,objective2,objective3" with value statement "statement 1, statement 2, statement 3"
* Assert backlog objective cannot have same name "Objective2"


Editing backlog objectives
* Rename backlog objective "objective2" as "Testing"
* Assert backlog objective "Testing" is present
* Click cancel on renaming "Testing" backlog objective as "newTesting"
* Assert backlog objective "Testing" is present

Set value,size for objectives
* Assert value slider for "objective3" at index "0" is at "0" percent
* Assert size slider for "objective3" at index "0" is at "0" percent
* Set value slider for "objective3" at index "0" to "50" percent
* Set size slider for "objective3" at index "0" to "50" percent
* Assert ratio for "objective3" at index "0" is equal to "1"
* Assert value slider for "objective3" at index "0" is at "50" percent
* Assert size slider for "objective3" at index "0" is at "50" percent

Veriy the Value statement set for Objectives
* Assert value statement set as "statement 1, statement 2, statement 3" for objectives "objective1,Testing,objective3" respectively

Verify count of backlog objective on Program page
* Navigate to programs list page
* Assert count of backlog objectives for program "First Plan" are "3"


Plan objectives from backlog
* Click backlog link for the program "First Plan"
* Plan objective "objective3" from backlog
* Switch to "months" view
* Assert that objective "objective3" is present
* Assert objective popup is present
* Click backlog link on the nav pill
* Assert backlog objective "objective3" is not present

Check readonly value statement on objective popup
* Open plan "First Plan"
* Open objective "objective3" popup
* Click on objective name "objective3" on popup
* Assert value statement "statement 3" on popup


Verify user cannot create objectives with same names as planned objectives
* Click backlog link on the nav pill
* Assert backlog objective cannot have same name as planned objective "objective3"

Associate projects with plan
* Open plan "First Plan"
* Open objective "objective3" popup
* Click "Add projects" link
* Associate projects "SAP" with program

Add work to objective
* Open plan "First Plan" in days view
* Switch to "months" view
* Open objective "objective3" popup
* Click addWork link
* Select project "SAP"
* Select cards "SAP_1, SAP_2,SAP_3,SAP_4"
* Add selected cards to objective


Move planned objectives with work  back to backlog
* Open plan "First Plan"
* Open objective "objective3" popup
* Choose to delete objective
* Assert text present "Moving this feature to your backlog will remove all content and project associations."
* Choose to move to backlog
* Assert text present "Feature objective3 has been moved to the backlog."
* Click backlog link on the nav pill
* Assert backlog objective "objective3" is present
* Assert value slider for "objective3" at index "2" is at "50" percent
* Assert size slider for "objective3" at index "2" is at "50" percent
* Assert ratio for "objective3" at index "2" is equal to "1"
* Assert value statement set as "statement 3" for objectives "objective3" respectively


Delete backlog objectives
* Create program "Cool Program"
* Click backlog link for the program "Cool Program"
* Create backlog objective "objective1,objective2" with value statement "statement 1, statement 2"
* Delete backlog objective at index "1"
* Delete backlog objective at index "0"
* Click backlog link on the nav pill
* Assert backlog objective "objective1" is not present
* Assert backlog objective "objective'2" is not present

___

Teardown of contexts
* Create projects "SAP" with "5" cards - teardown
* Login to mingle as "admin" - teardown


