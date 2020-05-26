BulkRemoveTeamMember
====================

tags: #12045, group_a

Setup of contexts
* Login to mingle as "admin" - setup
* Create program "Finance Program" with "30" team members - setup
* Create plan "Court Management" with "bob" as team member - setup
* Add users "longbob, bob" to program "Finance Program" - setup
* Create projects "SAP, Java" with cards - setup

BulkRemoveTeamMember
--------------------


Verify that no team members will be removed if user clicks the 'Remove' button without selecting any team members.

By verifiying the first and last user on current page doesn't change before and after user clicking the 'Remove' button, it's proved that no users actually are removed. Reason is: I don't want to check all the 25 users are there.

Although the sorting might not be guaranteed in this story, and you can say that my test depends on another potential testing point,  I'll be shocked if the sorting changes after user clicks a disabled button.

Last, let's pray that Oracle and PG has the same sorting strategy in this scenario.

* Navigate to team members list page of program "Finance Program"
* Assert that "admin" is the first user on current page
* Assert that "user_29" is the last user on current page
* Remove users
* Assert that "admin" is the first user on current page
* Assert that "user_29" is the last user on current page

Verify that user should see successfully message after team members are removed; also, the search keyword should not be cleared by removing.
* Search team members by "bob"
* Remove users "bob, longbob" from program
* Assert text present "2 members have been removed from the Finance Program team successfully."
* Assert that users "bob, longbob" are not displayed on team members list
* Assert that search query keyword is "bob"
* Clear the search query

Verify that the pagination should still be correct after user removes some team members.
* Open "2" page
* Remove users "user_9" from program
* Assert that users "user_9" are not displayed on team members list
* Assert that current page is page "2"

Verify that the user cannot see the program after his/her membership has been removed and that the user still can see the programs to which he/she still has membership.
* Login as "bob"
* Navigate to programs list page
* Assert that program "Court Management" is displayed on programs list
* Navigate to programs list page
* Assert that program is not displayed on programs list "Finance Program"


* Open plan "Finance Program" via url
* Assert that cannot access the requested resource


Verify that user becomes to a team candidate right after he/she is removed from a program.
* Login as "admin"
* Navigate to team members list page of program "Finance Program"
* Open add team members page
* Assert that users "bob" can be added to program
* Add user "bob" to program

Verify that the Mingle admin can remove himself/herself from the program, but still has access to and control of the program.
* Back to team members page
* Remove users "admin" from program
* Assert that users "admin" are not displayed on team members list

Verify that full mingle user cannot remove himself/herself from the program.
* Login as "bob"
* Navigate to team members list page of program "Finance Program"
* Remove users "bob" from program
* Assert text present "Cannot remove yourself from program"
* Assert that users "bob" are displayed on team members list

Verify that full mingle user can remove other team members from the program.
* Remove users "bob, user_1" from program
* Assert text present "Cannot remove yourself from program"
* Select users "user_1"
* Remove users
* Assert that users "user_1" are not displayed on team members list



___

Teardown of contexts
* Create projects "SAP, Java" with cards - teardown
* Add users "longbob, bob" to program "Finance Program" - teardown
* Create plan "Court Management" with "bob" as team member - teardown
* Create program "Finance Program" with "30" team members - teardown
* Login to mingle as "admin" - teardown


