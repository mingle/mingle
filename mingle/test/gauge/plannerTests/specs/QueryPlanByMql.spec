QueryPlanByMql
==============

tags: plan_page

Setup of contexts
* Login to mingle as "admin" - setup
* Create projects "SAP" with "6" cards - setup
* Create program with objectives "Finance" "Payroll,Billing" - setup
* Create program with objectives "Revenue" "State Tax" - setup
* Associate projects "SAP" with program "Finance" - setup
* Associate projects "SAP" with program "Revenue" - setup

QueryPlanByMql
--------------

Story #11310 (Be able to find card by plan in projects - mql).

Prepare the data
* Add card "2,4,5" from project "SAP" to plan "Finance" and assign to objective "Payroll"
* Add card "3,4" from project "SAP" to plan "Revenue" and assign to objective "State Tax"
* Create a wiki "QA corner" of project "SAP"

Support double quotes and single quotes for plan name in MQL
* Create a table macro with where clause of "In Plan \"Finance\"" in wiki "QA corner" of project "SAP"
* Assert that the cards "2,4,5" are displayed on page
* Create a table macro with where clause of "IN Plan 'Finance'" in wiki "QA corner" of project "SAP"
* Assert that the cards "2,4,5" are displayed on page

Support IN and NOT IN for plan name in MQL
* Create a table macro with where clause of "IN Plan Finance" in wiki "QA corner" of project "SAP"
* Assert that the cards "2,4,5" are displayed on page
* Create a table macro with where clause of "NOT IN Plan Finance" in wiki "QA corner" of project "SAP"
* Assert that the cards "1,3,6" are displayed on page

Support multiple plan query in MQL
* Create a table macro with where clause of "IN Plan \"Finance\" AND IN Plan \"Revenue\"" in wiki "QA corner" of project "SAP"
* Assert that the cards "4" are displayed on page
* Create a table macro with where clause of "IN Plan \"Finance\" OR IN Plan \"Revenue\"" in wiki "QA corner" of project "SAP"
* Assert that the cards "2,3,4,5" are displayed on page
* Create a table macro with where clause of "IN Plan Finance AND NOT IN Plan Revenue" in wiki "QA corner" of project "SAP"
* Assert that the cards "2,5" are displayed on page
* Create a table macro with where clause of "IN Plan Finance OR NOT IN Plan Revenue" in wiki "QA corner" of project "SAP"
* Assert that the cards "1,2,4,5,6" are displayed on page

Setup data for below scenario
* Create managed text property "Priority" in project "SAP" with values "High, Low"
* Set "Priority" in card number "1" of project "SAP" to "Low"
* Set "Priority" in card number "2" of project "SAP" to "High"
* Set "Priority" in card number "3" of project "SAP" to "Low"

Using IN Plan MQL with card propety
* Create a table macro with where clause of "IN Plan Finance AND priority = High" in wiki "QA corner" of project "SAP"
* Assert that the cards "2" are displayed on page
* Create a table macro with where clause of "(IN Plan Finance OR priority = High) AND IN Plan Revenue" in wiki "QA corner" of project "SAP"
* Assert that the cards "4" are displayed on page


MQL results get updated correct when plan has been updated
* Add card "1" from project "SAP" to plan "Finance" and assign to objective "Payroll"
* Create a table macro with where clause of "IN Plan Finance" in wiki "QA corner" of project "SAP"
* Assert that the cards "2,4,5" are displayed on page
* Add card "1" from project "SAP" to plan "Finance" and assign to objective "Billing"
* Navigate to wiki page "QA corner" of project "SAP"
* Assert that the cards "1,2,4,5" are displayed on page


___

Teardown of contexts
* Associate projects "SAP" with program "Revenue" - teardown
* Associate projects "SAP" with program "Finance" - teardown
* Create program with objectives "Revenue" "State Tax" - teardown
* Create program with objectives "Finance" "Payroll,Billing" - teardown
* Create projects "SAP" with "6" cards - teardown
* Login to mingle as "admin" - teardown


