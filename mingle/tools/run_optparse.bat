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

SET TOOL=%1
SHIFT
:CHECKOPTIONS
IF '%1'=='--mingle.dataDir' GOTO SETDATADIR
IF '%1'=='--mingle.configDir' GOTO SETCONFIGDIR
IF '%1'=='--mingle.logDir' GOTO SETLOGDIR
IF '%1'=='--filename' GOTO SETFIlENAME
IF '%1'=='--help' GOTO USAGE

IF NOT DEFINED MINGLE_DATA_DIR (
SET E=1
echo.
echo Mingle tools cannot be run without specifying a data directory. Run this tool with --mingle.dataDir=\path\to\dataDir to specify one.
echo.
GOTO USAGE
)

GOTO END

:SETDATADIR
SET MINGLE_DATA_DIR=%2
SHIFT
SHIFT
GOTO CHECKOPTIONS

:SETCONFIGDIR
SET MINGLE_CONFIG_DIR=%2
SHIFT
SHIFT
GOTO CHECKOPTIONS

:SETLOGDIR
SET MINGLE_LOG_DIR=%2
SHIFT
SHIFT
GOTO CHECKOPTIONS

:SETFIlENAME
SET FILE_NAME=%2
SHIFT
SHIFT
GOTO CHECKOPTIONS

:USAGE
TYPE tools\usage.hlp
SET E=1
GOTO END

:END
