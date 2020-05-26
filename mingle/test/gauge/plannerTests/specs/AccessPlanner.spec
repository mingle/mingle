AccessPlanner
=============
tags: plnner_access

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
Anonymous user part is still pending

* PlannerAccessForDifferentUsers
     |User Type     |Planner Availability?|
     |--------------|---------------------|
     |Mingle Admin  |Available            |
     |Readonly User |Available            |
     |Full User     |Available            |
     |Anonymous User|Unavailable          |