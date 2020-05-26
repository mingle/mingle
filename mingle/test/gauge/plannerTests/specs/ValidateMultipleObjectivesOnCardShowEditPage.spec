ValidateMultipleObjectivesOnCardShowEditPage
============================================

tags: objectives

Setup of contexts
* Enable messaging - setup
* Login to mingle as "admin" - setup
* Create program with objectives "Finance Program" "Payroll System,Billing System,Adding card to many objectives" - setup
* Create projects "SAP, Java" with "5" cards - setup
* Associate projects "SAP,Java" with program "Finance Program" - setup
* Create program with objectives "No objective Plan" "" - setup
* Associate projects "SAP" with program "No objective Plan" - setup

ValidateMultipleObjectivesOnCardShowEditPage
--------------------------------------------

Validate on card show

* Navigate to plan "Finance Program" objective "Payroll System" assign work page
* Select project "SAP"
* Set filter number "0" with property "Type" operator "is" and value "Card" on add work page
* Select cards "SAP_1, SAP_2"
* Add selected cards to objective
* Navigate to plan "Finance Program" objective "Billing System" assign work page
* Select project "SAP"
* Set filter number "0" with property "Type" operator "is" and value "Card" on add work page
* Enable auto sync
* ContinueAutoSync
* Run auto sync for project "SAP"


* Open card number "1" from project "SAP"
* Assert "Finance Program, No objective Plan" link present
* Assert link url of "Finance Program" is "/programs/finance_program/plan?project_id=sap"
* Assert link url of "No objective Plan" is "/programs/no_objective_plan/plan?project_id=sap"
* Assert that on card that card belongs to objective "Payroll System,Billing System" of plan "Finance Program"
* Assert edit objectives link is disabled for plan "No objective Plan"
* Click edit objectives link for plan "Finance Program"
* Assert objectives "Payroll System,Adding card to many objectives" are present on edit objectives popup
* Assert objectives "Payroll System" is checked
* Assert objectives "Billing System" is set for auto synced objective


Validate on card edit page
* Open card number "1" from project "SAP" to edit
* Assert that on card that card belongs to objective "Payroll System,Billing System" of plan "Finance Program"
* Assert edit objectives link is disabled for plan "No objective Plan"
* Click edit objectives link for plan "Finance Program"
* Assert objectives "Payroll System,Adding card to many objectives" are present on edit objectives popup
* Assert objectives "Payroll System" is checked
* Assert objectives "Billing System" is set for auto synced objective
* Check or un check objective "Adding card to many objectives"
* Save selected objective
* Assert that on card that card belongs to objective "Payroll System,Billing System,Adding card to many objectives" of plan "Finance Program"
* Click edit objectives link for plan "Finance Program"
* Assert objectives "Payroll System,Adding card to many objectives" is checked
* Click cancel edit objective popup
* Save card
* Assert that on card that card belongs to objective "Payroll System,Billing System,Adding card to many objectives" of plan "Finance Program"

validate save and add another
* Open card number "1" from project "SAP" to edit
* Save and add another card
* Assert that on card that card belongs to objective "Payroll System,Billing System,Adding card to many objectives" of plan "Finance Program"
* Click edit objectives link for plan "Finance Program"
* Check or un check objective "Adding card to many objectives"
* Save selected objective
* Assert that on card that card belongs to objective "Payroll System,Billing System" of plan "Finance Program"
* Assert that on card that card does not belongs to objective "Adding card to many objectives" of plan "Finance Program"
* Input card name "SAP_100"
* Save card
* Open card "SAP_100"
* Assert that on card that card belongs to objective "Payroll System,Billing System" of plan "Finance Program"
* Assert that on card that card does not belongs to objective "Adding card to many objectives" of plan "Finance Program"



___

Teardown of contexts
* Associate projects "SAP" with program "No objective Plan" - teardown
* Create program with objectives "No objective Plan" "" - teardown
* Associate projects "SAP,Java" with program "Finance Program" - teardown
* Create projects "SAP, Java" with "5" cards - teardown
* Create program with objectives "Finance Program" "Payroll System,Billing System,Adding card to many objectives" - teardown
* Login to mingle as "admin" - teardown
* Enable messaging - teardown


