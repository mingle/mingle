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

// JUnit Assert framework can be used for verification

import com.thoughtworks.mingle.planner.smokeTest.util.JRubyScriptRunner;
import com.thoughtworks.mingle.planner.smokeTest.util.JRubyScriptRunner.ScriptBuilder;
import com.thoughtworks.mingle.planner.smokeTest.util.JRubyScriptRunner.ScriptWriter;

public class CreateBaselinePlan {

    private final JRubyScriptRunner scriptRunner;

    public CreateBaselinePlan(JRubyScriptRunner jRubyScriptRunner) {
        this.scriptRunner = jRubyScriptRunner;
    }

    public void setUp() throws Exception {
        scriptRunner.setDebugMode(true);
        scriptRunner.executeWithTestHelpers(new ScriptBuilder() {

            public void build(ScriptWriter scriptWriter) {
                scriptWriter.printfln("project_java = create_project(:name => 'Java')");
                scriptWriter.printfln("project_sap = create_project(:name => 'SAP')");

                scriptWriter.printfln("project_java.with_active_project do");
                scriptWriter.printfln("  status = setup_managed_text_definition('Status', ['Open', 'In-progress', 'Completed'])");
                scriptWriter.printfln("  release = setup_card_type(project_java, 'Release', :properties => [status])");
                scriptWriter.printfln("  iteration = setup_card_type(project_java, 'Iteration', :properties => [status])");
                scriptWriter.printfln("  story = setup_card_type(project_java, 'Story', :properties => [status])");
                scriptWriter.printfln("  [release, iteration, story].each do |card_type| ");
                scriptWriter.printfln("    create_card!(:name => \"#{card_type.name} 1 in project Java\", :card_type => card_type)");
                scriptWriter.printfln("    create_card!(:name => \"#{card_type.name} 2 in project Java\", :card_type => card_type)");
                scriptWriter.printfln("    create_card!(:name => \"#{card_type.name} 3 in project Java\", :card_type => card_type)");
                scriptWriter.printfln("  end");
                scriptWriter.printfln("end");

                scriptWriter.printfln("project_sap.with_active_project do");
                scriptWriter.printfln("  story_status = setup_managed_text_definition('Story Status', ['New', 'Accepted'])");
                scriptWriter.printfln("  release = setup_card_type(project_sap, 'Release', :properties => [story_status])");
                scriptWriter.printfln("  iteration = setup_card_type(project_sap, 'Iteration', :properties => [story_status])");
                scriptWriter.printfln("  story = setup_card_type(project_sap, 'Story', :properties => [story_status])");
                scriptWriter.printfln("  [release, iteration, story].each do |card_type| ");
                scriptWriter.printfln("    create_card!(:name => \"#{card_type.name} 1 in project SAP\", :card_type => card_type)");
                scriptWriter.printfln("    create_card!(:name => \"#{card_type.name} 2 in project SAP\", :card_type => card_type)");
                scriptWriter.printfln("    create_card!(:name => \"#{card_type.name} 3 in project SAP\", :card_type => card_type)");
                scriptWriter.printfln("  end");
                scriptWriter.printfln("end");

                scriptWriter.printfln("program = create_program('Finance')");
                scriptWriter.printfln("payroll = create_planned_objective(program, :name => 'Payroll', :start_at => '2010 Mar 1', :end_at => '2010 Mar 8', :vertical_position => 1)");
                scriptWriter.printfln("billing = create_planned_objective(program, :name => 'Billing', :start_at => '2010 Mar 5', :end_at => '2010 Mar 18', :vertical_position => 3)");

                scriptWriter.printfln("program.update_project_status_mapping(project_sap, :status_property_name => 'Story Status', :done_status => 'Accepted')");
                scriptWriter.printfln("program.update_project_status_mapping(project_java, :status_property_name => 'Status', :done_status => 'Completed')");

                scriptWriter.printfln("payroll.assign_cards(project_java, :numbers => [1, 2])");
                scriptWriter.printfln("payroll.assign_cards(project_sap, :numbers => [1, 2])");
                scriptWriter.printfln("billing.assign_cards(project_java, :numbers => [3, 4])");
                scriptWriter.printfln("billing.assign_cards(project_sap, :numbers => [3, 4])");
            }
        });
        scriptRunner.setDebugMode(false);
    }

    public void tearDown() throws Exception {}

}
