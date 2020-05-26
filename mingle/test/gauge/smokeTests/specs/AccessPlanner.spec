AccessPlanner
=============

tags: Plan, #11160, licensing and access, group_a

Setup of contexts
* Enable real license decryption - setup
* Create projects "SAP" with cards - setup
* Login to mingle as "admin" - setup
* Register license of type "Planner license with Anonymous access" - setup
* Enable anonymous access for project "SAP" - setup

AccessPlanner
-------------

Story #11160 (Show Planner as part of Mingle)
For now every logged in user can access and create a plan, so that is what we are verifying. This will almost certainly change in the future.


* PlannerAccessForDifferentUsers 
     |User Type     |Planner Availability?|
     |--------------|---------------------|
     |Mingle Admin  |Available            |
     |Readonly User |Available            |
     |Full User     |Available            |
     |Anonymous User|Unavailable          |




___

Teardown of contexts
* Enable anonymous access for project "SAP" - teardown
* Register license of type "Planner license with Anonymous access" - teardown
* Login to mingle as "admin" - teardown
* Create projects "SAP" with cards - teardown
* Enable real license decryption - teardown


