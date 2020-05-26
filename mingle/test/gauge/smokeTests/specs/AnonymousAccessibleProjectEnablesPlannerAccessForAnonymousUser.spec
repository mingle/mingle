AnonymousAccessibleProjectEnablesPlannerAccessForAnonymousUser
==============================================================

tags: bug, #12393, group_a

Setup of contexts
* Create projects "SAP, Java" with cards - setup
* Create program with objectives "Finance Program" "Payroll System" - setup
* Enable real license decryption - setup
* Login to mingle as "admin" - setup
* Register license of type "Planner license with Anonymous access" - setup

AnonymousAccessibleProjectEnablesPlannerAccessForAnonymousUser
--------------------------------------------------------------

bug #12393 (Anonynous user can access Planner if there are anonymous accesible project(s)).

* Open plan "Finance Program" via url
* Assert that current page is login page
* Login as "admin"
* Enable anonymous access for project "SAP"
* Login as anon user
* Open plan "Finance Program" via url
* Assert that current page is login page



___

Teardown of contexts
* Register license of type "Planner license with Anonymous access" - teardown
* Login to mingle as "admin" - teardown
* Enable real license decryption - teardown
* Create program with objectives "Finance Program" "Payroll System" - teardown
* Create projects "SAP, Java" with cards - teardown


