BulkUpdateDoneStatus
====================

tags: add_remove_work

Setup of contexts
* Login to mingle as "admin" - setup
* Create projects "SAP" with "4" cards - setup
* Create program with objectives "Finance Program" "Payroll System" - setup
* Associate projects "SAP" with program "Finance Program" - setup

BulkUpdateDoneStatus
--------------------

* Create managed text property "Status" in project "SAP" with values "Open, In Progress, QA Complete"

* Navigate to plan "Finance Program" objective "Payroll System" assign work page
* Select project "SAP"
* Select cards "SAP_4, SAP_3, SAP_2, SAP_1"
* Add selected cards to objective
* View all work for "Payroll System" objective
* Assert that the status column for cards "SAP_1" is "\"Done\" status not defined for project"
* Assert that the status column for cards "SAP_2" is "\"Done\" status not defined for project"
* Assert that the status column for cards "SAP_3" is "\"Done\" status not defined for project"
* Assert that the status column for cards "SAP_4" is "\"Done\" status not defined for project"
* Navigate to program "Finance Program" projects page
* Open define done status page of project "SAP"
* Map property "Status" value "QA Complete" to plan done status
* View all work for "Payroll System" objective
* Assert that the status column for cards "SAP_1" is "Not done"
* Assert that the status column for cards "SAP_2" is "Not done"
* Assert that the status column for cards "SAP_3" is "Not done"
* Assert that the status column for cards "SAP_4" is "Not done"

* Bulk update "Status" of cards number "SAP_1, SAP_2" of project "SAP" from "(not set)" to "QA Complete"
* Bulk update "Status" of cards number "SAP_3, SAP_4" of project "SAP" from "(not set)" to "Open"

* Open plan "Finance Program"
* View all work for "Payroll System" objective
* Assert that the status column for cards "SAP_1" is "Done"
* Assert that the status column for cards "SAP_2" is "Done"
* Assert that the status column for cards "SAP_3" is "Not done"
* Assert that the status column for cards "SAP_4" is "Not done"


___

Teardown of contexts
* Associate projects "SAP" with program "Finance Program" - teardown
* Create program with objectives "Finance Program" "Payroll System" - teardown
* Create projects "SAP" with "4" cards - teardown
* Login to mingle as "admin" - teardown


