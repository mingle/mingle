DeleteObjective
===============
tags: objectives

Setup of contexts
* Create projects "SAP, Java" with cards - setup
* Create program with objectives "Finance Program" "Payroll System, Billing System" - setup
* Associate projects "SAP,Java" with program "Finance Program" - setup
* Login to mingle as "admin" - setup

DeleteObjective
---------------
Story #11378 - Be able to delete objective with work and without work items.

Should see warning message when deleting a objective although it has no work associated.
* Navigate to objective "Payroll System" of plan "Finance Program"
* Choose to delete objective
* Assert text present "Remove from plan"

Delete a objective with cards.
* Navigate to objective "Payroll System" of plan "Finance Program"
* Open add works page
* Add cards with numbers "1" from project "SAP"
* Add cards with numbers "2" from project "Java"
* Navigate to objective "Payroll System" of plan "Finance Program"
* Choose to delete objective
* Continue to delete objective
* Assert that objective "Payroll System" is not present
* Open card number "1" from project "SAP" to edit
* Assert that the plan "Finance Program" is on card
* Assert that on card that card belongs to objective "(not set)" of plan "Finance Program"


Moving an objective with cards to backlog.
* Navigate to objective "Billing System" of plan "Finance Program"
* Open add works page
* Add cards with numbers "1" from project "SAP"
* Add cards with numbers "2" from project "Java"
* Navigate to objective "Billing System" of plan "Finance Program"
* Choose to delete objective
* Choose to move to backlog
* Assert that objective "Billing System" is not present


* Open card number "1" from project "SAP" to edit
* Assert that the plan "Finance Program" is on card
* Assert that on card that card belongs to objective "(not set)" of plan "Finance Program"


___

Teardown of contexts
* Login to mingle as "admin" - teardown
* Associate projects "SAP,Java" with program "Finance Program" - teardown
* Create program with objectives "Finance Program" "Payroll System, Billing System" - teardown
* Create projects "SAP, Java" with cards - teardown


