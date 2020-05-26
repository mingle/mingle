@echo off
rem vim: ai et sts=2 sw=2

rem  Copyright 2020 ThoughtWorks, Inc.
rem
rem  This program is free software: you can redistribute it and/or modify
rem  it under the terms of the GNU Affero General Public License as
rem  published by the Free Software Foundation, either version 3 of the
rem  License, or (at your option) any later version.
rem
rem  This program is distributed in the hope that it will be useful,
rem  but WITHOUT ANY WARRANTY; without even the implied warranty of
rem  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
rem  GNU Affero General Public License for more details.
rem
rem  You should have received a copy of the GNU Affero General Public License
rem  along with this program.  If not, see <https://www.gnu.org/licenses/agpl-3.0.txt>.

setlocal EnableDelayedExpansion
set _cp=

rem change to the Rails.root directory so we can find our jars
rem   - in case you're wondering, the %dp0 macro represents the dirname of the current file
cd %~dp0..

set start_jar=webapps/ROOT/WEB-INF/lib/start.jar

rem load these libraries first to take precedence. we'll load everything else after this.
set initial_libraries=^
  %start_jar% ^
  webapps/ROOT/WEB-INF/config ^
  webapps/ROOT/WEB-INF/development/build_java/j2ssh-core-0.2.9.jar

rem and then anything else
for %%j in (webapps/ROOT/WEB-INF/lib/*.jar) do (set _cp=!_cp!;webapps/ROOT/WEB-INF/lib/%%j)

for %%j in (%initial_libraries%) do (set _cp=!_cp!;%%j)

rem the :~1 syntax removes the semicolon at the beginning of the string
endlocal&set CLASSPATH=%_cp:~1%

exit /b
