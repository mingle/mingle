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

package com.thoughtworks.mingle.planner.administration;

import org.apache.commons.lang.StringUtils;

import com.thoughtworks.mingle.planner.smokeTest.util.JRubyScriptRunner;
import com.thoughtworks.mingle.planner.smokeTest.util.JRubyScriptRunner.ScriptBuilder;
import com.thoughtworks.mingle.planner.smokeTest.util.JRubyScriptRunner.ScriptWriter;

public class ProjectAdministration {

    private final JRubyScriptRunner scriptRunner;

    public ProjectAdministration(JRubyScriptRunner jRubyScriptRunner) {
        this.scriptRunner = jRubyScriptRunner;
    }

    public void createProjectsWithCards(final String projectNames, final Integer numberOfCards) throws Exception {
        this.scriptRunner.executeWithTestHelpers(new ScriptBuilder() {
            public void build(ScriptWriter scriptWriter) {
                for (String projectName : projectNames.split(",")) {
                    scriptWriter.printfln("create_project(:name => '%s').with_active_project do |project|", projectName);
                    for (int i = 1; i <= numberOfCards; i++) {
                        scriptWriter.printfln("create_card!(:name => 'Card %d')", i);
                    }
                    scriptWriter.printfln("end");
                }
            }
        });
    }

    public void cardChangesHistoryGeneration() throws Exception {
        this.scriptRunner.executeWithTestHelpers(new ScriptBuilder() {
            public void build(ScriptWriter scriptWriter) {
                scriptWriter.printfln("HistoryGeneration.run_once");
            }
        });
    }

    @com.thoughtworks.gauge.Step("Create any text property <propertyName> in project <projectName>")
	public void createAnyTextPropertyInProject(final String propertyName, final String projectName) throws Exception {
        this.scriptRunner.executeWithTestHelpers(new ScriptBuilder() {
            public void build(ScriptWriter scriptWriter) {
                scriptWriter.printfln("Project.find_by_name('%s').with_active_project do |project|", projectName);
                scriptWriter.printfln("  setup_allow_any_text_property_definition('%s')", propertyName);
                scriptWriter.printfln("end");
            }
        });

    }

    @com.thoughtworks.gauge.Step("Create managed text property <propertyName> in project <projectName> with values <propertyValues>")
	public void createManagedTextPropertyInProjectWithValues(final String propertyName, final String projectName, final String propertyValues) throws Exception {
        this.scriptRunner.executeWithTestHelpers(new ScriptBuilder() {
            public void build(ScriptWriter scriptWriter) {
                scriptWriter.printfln("Project.find_by_name('%s').with_active_project do |project|", projectName);
                scriptWriter.printfln("  setup_managed_text_definition('%s', %s)", propertyName, commaListToRubyStringArray(propertyValues));
                scriptWriter.printfln("end");
            }
        });
    }

    @com.thoughtworks.gauge.Step("Create managed number property <propertyName> in project <projectName> with values <propertyValues>")
	public void createManagedNumberPropertyInProjectWithValues(final String propertyName, final String projectName, final String propertyValues) throws Exception {
        this.scriptRunner.executeWithTestHelpers(new ScriptBuilder() {
            public void build(ScriptWriter scriptWriter) {
                scriptWriter.printfln("Project.find_by_name('%s').with_active_project do |project|", projectName);
                scriptWriter.printfln("  setup_managed_number_list_definition('%s', %s)", propertyName, commaListToRubyStringArray(propertyValues));
                scriptWriter.printfln("end");
            }
        });
    }

    @com.thoughtworks.gauge.Step("Create hidden managed text property <propertyName> in project <projectName> with values <propertyValues>")
	public void createHiddenManagedTextPropertyInProjectWithValues(final String propertyName, final String projectName, final String propertyValues) throws Exception {
        this.scriptRunner.executeWithTestHelpers(new ScriptBuilder() {
            public void build(ScriptWriter scriptWriter) {
                scriptWriter.printfln("Project.find_by_name('%s').with_active_project do |project|", projectName);
                scriptWriter.printfln("  setup_managed_text_definition('%s', %s)", propertyName, commaListToRubyStringArray(propertyValues));
                scriptWriter.printfln("  project.find_property_definition('%s').update_attributes(:hidden => true)", propertyName);
                scriptWriter.printfln("end");
            }
        });
    }

    @com.thoughtworks.gauge.Step("Set <propertyName> in card number <cardNumber> of project <projectName> to <propertyValue>")
	public void setInCardNumberOfProjectTo(final String propertyName, final Integer cardNumber, final String projectName, final String propertyValue) throws Exception {
        this.scriptRunner.executeWithTestHelpers(new ScriptBuilder() {
            public void build(ScriptWriter scriptWriter) {
                scriptWriter.printfln("Project.find_by_name('%s').with_active_project do |project|", projectName);
                scriptWriter.printfln("  property = PropertyDefinition.find_by_name('%s')", propertyName);
                scriptWriter.printfln("  card = project.cards.find_by_number('%d')", cardNumber);
                scriptWriter.printfln("  property.update_card(card, '%s')", propertyValue);
                scriptWriter.printfln("  card.save!");
                scriptWriter.printfln("end");
            }
        });
    }

    public void enableAnonymousAccessForProject(final String projectName) throws Exception {
        this.scriptRunner.executeWithTestHelpers(new ScriptBuilder() {

            public void build(ScriptWriter scriptWriter) {
                scriptWriter.printfln("Project.find_by_name('%s').with_active_project do |project|", projectName);
                scriptWriter.printfln(" project.update_attribute(:anonymous_accessible, true)");
                scriptWriter.printfln("end");
            }
        });
    }

    public void createCardsNumberedOfProject(final String cardType, final String cardNumbers, final String projectName) throws Exception {
        scriptRunner.executeWithTestHelpers(new ScriptBuilder() {
            public void build(ScriptWriter scriptWriter) {
                scriptWriter.printfln("project = Project.find_by_name('%s')", projectName);
                scriptWriter.printfln("project.with_active_project do |project|");
                for (String number : cardNumbers.split(",")) {
                    scriptWriter.printfln("create_card!(:name => 'sample card', :card_type => '%s', :number => '%s')", cardType, number);
                }
                scriptWriter.printfln("end");
            }
        });
    }

    @com.thoughtworks.gauge.Step("Add user <login> as readonly member to project <projectName>")
	public void addUserAsReadonlyMemberToProject(final String login, final String projectName) throws Exception {
        scriptRunner.executeWithTestHelpers(new ScriptBuilder() {
            public void build(ScriptWriter scriptWriter) {
                scriptWriter.printfln("user = User.find_by_login('%s')", login);
                scriptWriter.printfln("project = Project.find_by_name('%s')", projectName);
                scriptWriter.printfln("project.with_active_project do |p|");
                scriptWriter.printfln("    p.add_member(user, :readonly_member)");
                scriptWriter.printfln("end");
            }
        });
    }

    @com.thoughtworks.gauge.Step("Add user <login> as full member to project <projectName>")
	public void addUserAsFullMemberToProject(final String login, final String projectName) throws Exception {
        scriptRunner.executeWithTestHelpers(new ScriptBuilder() {
            public void build(ScriptWriter scriptWriter) {
                scriptWriter.printfln("user = User.find_by_login('%s')", login);
                scriptWriter.printfln("project = Project.find_by_name('%s')", projectName);
                scriptWriter.printfln("project.with_active_project do |p|");
                scriptWriter.printfln("    p.add_member(user)");
                scriptWriter.printfln("end");
            }
        });
    }

    @com.thoughtworks.gauge.Step("Add user <login> as project admin to project <projectName>")
	public void addUserAsProjectAdminToProject(final String login, final String projectName) throws Exception {
        scriptRunner.executeWithTestHelpers(new ScriptBuilder() {
            public void build(ScriptWriter scriptWriter) {
                scriptWriter.printfln("user = User.find_by_login('%s')", login);
                scriptWriter.printfln("project = Project.find_by_name('%s')", projectName);
                scriptWriter.printfln("project.with_active_project do |p|");
                scriptWriter.printfln("    p.add_member(user, :project_admin)");
                scriptWriter.printfln("end");
            }
        });
    }

    public void associateProjectsWithProgram(final String projectNames, final String programName) throws Exception {
        scriptRunner.executeWithTestHelpers(new ScriptBuilder() {
            public void build(ScriptWriter scriptWriter) {
                scriptWriter.printfln("program = Program.find_by_name('%s')", programName);
                for (String projectName : projectNames.split(",")) {
                    scriptWriter.printfln("project = Project.find_by_name('%s')", projectName);
                    scriptWriter.printfln("program.projects << project");
                }
            }
        });
    }

    public void addProjectCardsNumberToPlanObjective(final String projectName, final String cardNumbers, final String planName, final String objectiveName) throws Exception {
        scriptRunner.executeWithTestHelpers(new ScriptBuilder() {
            public void build(ScriptWriter scriptWriter) {
                scriptWriter.printfln("program = Program.find_by_name('%s')", planName);
                scriptWriter.printfln("project = Project.find_by_name('%s')", projectName);
                scriptWriter.printfln("objective = program.objectives.planned.find_by_name('%s')", objectiveName);
                scriptWriter.printfln("program.plan.assign_cards(project, [%s], objective)", cardNumbers);
            }
        });
    }

    // Private methods

    private String commaListToRubyStringArray(String commaSeparatedValues) {
        String[] values = commaSeparatedValues.split(",");
        StringBuilder builder = new StringBuilder();
        if (!commaSeparatedValues.equals("")) {
            builder.append("['");
            builder.append(StringUtils.join(values, "','"));
            builder.append("']");
        } else {
            builder.append("[]");
        }
        return builder.toString();
    }

}
