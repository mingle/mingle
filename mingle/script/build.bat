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

@echo off

call "%~dp0devenv.bat"

call jruby -S gem uninstall -I -x bundler
call jruby -S gem install bundler -v 1.11.2

call bundle install

call bundle exec %*
