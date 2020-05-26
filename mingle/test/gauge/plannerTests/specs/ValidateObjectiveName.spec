ValidateObjectiveName
=====================
tags: objectives

Setup of contexts
* Create program with objectives "Finance Program" "Payroll System, State Tax" - setup
* Login to mingle as "admin" - setup

ValidateObjectiveName
---------------------

Test story #11411 - objective name must unique and cannot be blank,  story #11509 - objective name should only allow certain characters when EDIT  objective

* Navigate to edit plan "Finance Program" objective "Payroll System"
* Update objective to ""
* Assert text present "Name can't be blank"
* Update objective to "  State   tax  "
* Assert text present "Name already used for an existing Feature."
* Update objective to "Mingle 4 0 rocks "
* Assert text present "Mingle 4 0 rocks was successfully updated"
* Open plan "Finance Program" in days view
* Navigate to edit plan "Finance Program" objective "Mingle 4 0 rocks"
* Update objective to "Mingle50 release is awesome with planner"


___

Teardown of contexts
* Login to mingle as "admin" - teardown
* Create program with objectives "Finance Program" "Payroll System, State Tax" - teardown


