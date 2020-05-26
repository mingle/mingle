AddRemoveWorkFromProject
========================

tags: add_remove_work

Setup of contexts
* Login to mingle as "admin" - setup
* Create projects "SAP, Java" with cards - setup
* Create program with objectives "Finance Program" "Payroll System, Billing System" - setup
* Associate projects "SAP, Java" with program "Finance Program" - setup

AddRemoveWorkFromProject
----------------------
Story #13565 Add work to objective from card show page. The story talks about adding or removing work on to the objective through card show/Edit page

Adding a card to objective from card show page
* Open card number "1" from project "SAP"
* Assert that the plan "Finance Program" is on card
* Select objective for plan "Payroll System" "Finance Program"
* Assert that on card that card belongs to objective "Payroll System" of plan "Finance Program"

* Open plan "Finance Program"
* Click on viewWork in the objective "Payroll System"
* Assert that cards "SAP_1" of project "SAP" are present in work table

Update objective in card edit page
* Open card number "1" from project "SAP" to edit
* Assert that the plan "Finance Program" is on card
* Select objective for plan "Billing System" "Finance Program"
* Save and add another card with name "SAP_100"
* Open card number "1" from project "SAP"
* Assert that on card that card belongs to objective "Payroll System,Billing System" of plan "Finance Program"

* Open plan "Finance Program"
* Click on viewWork in the objective "Billing System"
* Assert that cards "SAP_1" of project "SAP" are present in work table
* Assert that card number "4" of project "SAP" are present in work table


Remove work from a objective in planner
* Select cards "1" from project "SAP" on work page
* Remove selected work items from objective
* Open plan "Finance Program"
* Click on viewWork in the objective "Payroll System"
* Select cards "1" from project "SAP" on work page
* Remove selected work items from objective


* Open card number "1" from project "SAP" to edit
* Assert that on card that card belongs to objective "(not set)" of plan "Finance Program"


add work in planner should reflect on card
* Navigate to plan "Finance Program" objective "Payroll System" assign work page
* Add cards "SAP_1" from "SAP" project to current objective

* Open card number "1" from project "SAP"
* Assert that on card that card belongs to objective "Payroll System" of plan "Finance Program"

Copy to... another project should not pass on plan association
* Copy card to project "Java" and open it
* Assert that the plan "Finance Program" is on card
* Assert that on card that card belongs to objective "(not set)" of plan "Finance Program"


remove card from the objective
* Open card number "1" from project "SAP"
* Deselect objective for plan "Payroll System" "Finance Program"
* Assert that on card that card belongs to objective "(not set)" of plan "Finance Program"

* Open plan "Finance Program"
* Click on viewWork in the objective "Payroll System"
* Assert that cards "1" of project "SAP" not present in work table

___

Teardown of contexts
* Associate projects "SAP, Java" with program "Finance Program" - teardown
* Create program with objectives "Finance Program" "Payroll System, Billing System" - teardown
* Create projects "SAP, Java" with cards - teardown
* Login to mingle as "admin" - teardown


