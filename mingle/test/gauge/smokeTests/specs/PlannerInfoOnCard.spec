PlannerInfoOnCard
=================

tags: #12047, Planner on card, group_a

Setup of contexts
* Login to mingle as "admin" - setup
* Create program with objectives "Finance Program" "Payroll System" - setup
* Create projects "SAP" with cards - setup
* Associate projects "SAP" with program "Finance Program" - setup
* Enable real license decryption - setup
* Enable anonymous access for project "SAP" - setup

PlannerInfoOnCard
-----------------

Story #12047 (Do not allow anybody to modify plan data in the project)

Verify that planner info should be displayed on card show and card edit page.

* Register license of the type "Planner license with Anonymous access"


* Add card "1" from project "SAP" to plan "Finance Program" and assign to objective "Payroll System"
* Open card number "1" from project "SAP"
* Assert that on card that card belongs to objective "Payroll System" of plan "Finance Program"
* Open card number "1" from project "SAP" to edit
* Assert that on card that card belongs to objective "Payroll System" of plan "Finance Program"

Verify that all users can see the card should also see planner info on card.
* Add user "read_only_user" as readonly member to project "SAP"
* Add user "bob" as full member to project "SAP"
* Add user "proj_admin" as project admin to project "SAP"
* Login as "bob"
* Open card number "1" from project "SAP"
* Assert that on card that card belongs to objective "Payroll System" of plan "Finance Program"
* Login as anon user
* Open card number "1" from project "SAP"
* Assert that on card that card belongs to objective "Payroll System" of plan "Finance Program"
* Login as "bob"
* Open card number "1" from project "SAP"
* Assert that on card that card belongs to objective "Payroll System" of plan "Finance Program"
* Open card number "1" from project "SAP" to edit
* Assert that on card that card belongs to objective "Payroll System" of plan "Finance Program"

Verify no one can see planner info on card if license doesn't support Planner.
* Login as "admin"
* Register license of the type "Valid Mingle license without Planner access"
* Login as anon user
* Open card number "1" from project "SAP"
* Assert that cannot see planner info on card
* Login as "read_only_user"
* Open card number "1" from project "SAP"
* Assert that cannot see planner info on card
* Login as "proj_admin"
* Open card number "1" from project "SAP"
* Assert that cannot see planner info on card
* Open card number "1" from project "SAP" to edit
* Assert that cannot see planner info on card

Change license back to Planner-supported user should be able to see planner info again.
* Login as "admin"
* Register license of the type "Valid Mingle license with Planner access"
* Login as "bob"
* Open card number "1" from project "SAP"
* Assert that on card that card belongs to objective "Payroll System" of plan "Finance Program"

Verify that should not see planner info on old card versions.
* Update card name to "sample card"
* Assert that on card that card belongs to objective "Payroll System" of plan "Finance Program"
* Open card version "1" for card "1" from project "SAP"
* Assert that cannot see planner info on card


___

Teardown of contexts
* Enable anonymous access for project "SAP" - teardown
* Enable real license decryption - teardown
* Associate projects "SAP" with program "Finance Program" - teardown
* Create projects "SAP" with cards - teardown
* Create program with objectives "Finance Program" "Payroll System" - teardown
* Login to mingle as "admin" - teardown

