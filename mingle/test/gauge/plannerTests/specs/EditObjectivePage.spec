EditObjectivePage
=================
tags: objectives

Setup of contexts
* Login to mingle as "admin" - setup
* Create program with objectives "Finance Program" "Billing System" - setup

EditObjectivePage
-----------------

* Navigate to objective "Billing System" of plan "Finance Program"
* Edit objective with new name "Payroll System" new start date "" new end date ""
* Save objective edit
* Assert notice text present "Start date can't be blank - End date can't be blank"
* Update objective with new start date "" new end date "6 Feb 2011"
* Save objective edit
* Assert text present "Start date can't be blank"
* Update objective with new start date "4 Feb 2011" new end date "10 Jan 2011"
* Save objective edit
* Assert text present "End date should be after start date"
* Cancel objective editing
* Assert current page is "/programs/finance_program/plan"


___

Teardown of contexts
* Create program with objectives "Finance Program" "Billing System" - teardown
* Login to mingle as "admin" - teardown


