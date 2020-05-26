ValidateProgramName
===================
tags: program_page

Setup of contexts
* Login to mingle as "admin" - setup

ValidateProgramName
-------------------

Test story #11509 - Objective and plan names should only allow certain characters, story #11412 - Plan names must be unique

Duplicate program names are not allowed
* DuplicateProgramNameVariations 
     |program name      |error message?             |
     |------------------|---------------------------|
     |Finance Program   |                           |
     |                  |Name can't be blank        |
     |Finance Program   |Name has already been taken|
     |Finance Program   |Name has already been taken|
     |Finance Program   |Name has already been taken|
     |Finance    Program|Name has already been taken|

Validate Program names variations
* ProgramNameWithSpecialCharacters
     |program name                            |name displayed?                         |
     |----------------------------------------|----------------------------------------|
     |Mingle 3.3                              |Mingle 3.3                              |
     |Macy's                                  |Macy's                                  |
     |Mingle40 release is awesome with planner|Mingle40 release is awesome with planner|
     |Oracle support (11g)                    |Oracle support (11g)                    |
     |管中窥豹                            |管中窥豹                            |




___

Teardown of contexts
* Login to mingle as "admin" - teardown


