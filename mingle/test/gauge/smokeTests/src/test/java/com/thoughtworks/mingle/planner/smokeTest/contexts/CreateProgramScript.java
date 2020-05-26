/*
*  Copyright 2020 ThoughtWorks, Inc.
*  
*  This program is free software: you can redistribute it and/or modify
*  it under the terms of the GNU Affero General Public License as
*  published by the Free Software Foundation, either version 3 of the
*  License, or (at your option) any later version.
*  
*  This program is distributed in the hope that it will be useful,
*  but WITHOUT ANY WARRANTY; without even the implied warranty of
*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*  GNU Affero General Public License for more details.
*  
*  You should have received a copy of the GNU Affero General Public License
*  along with this program.  If not, see <https://www.gnu.org/licenses/agpl-3.0.txt>.
*/

package com.thoughtworks.mingle.planner.smokeTest.contexts;

import com.thoughtworks.mingle.planner.smokeTest.util.JRubyScriptRunner.ScriptBuilder;
import com.thoughtworks.mingle.planner.smokeTest.util.JRubyScriptRunner.ScriptWriter;
import com.thoughtworks.mingle.planner.smokeTest.util.HelperUtils;

final class CreateProgramScript implements ScriptBuilder {

    private final String planName;

    CreateProgramScript(String planName) {
        this.planName = planName;
    }

    public void build(ScriptWriter scriptWriter) {
        scriptWriter.printfln("program = Program.create!(:identifier => '%s', :name => '%s')", HelperUtils.nameToIdentifier(planName), planName);
        scriptWriter.printfln("program.plan.update_attributes(:start_at => '2011-01-01', :end_at => '2011-02-01')");
    }
}
