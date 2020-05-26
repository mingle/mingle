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

package com.thoughtworks.mingle.planner.smokeTest.utils;

import java.io.PrintWriter;
import java.io.StringWriter;

import org.apache.commons.httpclient.HttpClient;
import org.apache.commons.httpclient.methods.PostMethod;


public class JRubyScriptRunner extends Constants {

    /** Set this to true using spring to output all executed ruby */
    private boolean debugMode = true;

    /**
     * Callback interface for building ruby code inline
     */
    public interface ScriptBuilder {

        /**
         * @param scriptWriter
         */
        public void build(ScriptWriter scriptWriter);
    }

    /**
     * Decorates a {@link PrintWriter} to give it the helpful method printfln, which runs printf with a newline.
     */
    public class ScriptWriter {

        private final PrintWriter printWriter;

        public ScriptWriter(PrintWriter printWriter) {
            this.printWriter = printWriter;
        }

        /**
         * Delegates to {@link PrintWriter}{@link #println(String)} If you want to use variable substitution, use {@link #printfln(String, Object...)}
         *
         * @param line
         */
        public void println(String line) {
            this.printWriter.println(line);
        }

        /**
         * Combines printf and println from PrintWriter into one call for convenience. Equivalent to println(String.format(...)) For our purposes, you can safely use %s for all data types. See http://download
         * .oracle.com/javase/1.5.0/docs/api/java/util/Formatter.html#syntax for all the supported options.
         *
         * @param format
         * @param args
         */
        public void printfln(String format, Object... args) {
            this.printWriter.println(String.format(format, args));
        }

    }

    // private final Ruby runtime;

    /**
     * Initializes a new JRuby runtime and boots rails
     *
     * @param defaultValues
     */
    public JRubyScriptRunner() {
        executeRaw("require \"#{Rails.root}/test/test_helper\"");
        executeRaw("Test::Unit.run = true");
    }

    /**
     * Executes the code built by scriptBuilder as a method in a subclass of ActiveSupport::TestCase which allows you to use the test helper methods we've defined.
     *
     * @param scriptBuilder
     *            Callback to build your script
     * @return The result of evaluating the supplied script. It will be nil unless you assign a value to the variable "return_value"
     */
    public void executeWithTestHelpers(final ScriptBuilder scriptBuilder) {
        executeWithBuilder(new ScriptBuilder() {
            public void build(ScriptWriter scriptWriter) {
                scriptWriter.printfln("class TwistTest < ActiveSupport::TestCase");
                scriptWriter.printfln("  def dynamic_code");
                scriptWriter.printfln("    return_value = nil");
                scriptWriter.printfln("    User.with_first_admin do");
                scriptBuilder.build(scriptWriter);
                scriptWriter.printfln("    end");
                scriptWriter.printfln("    return_value");
                scriptWriter.printfln("  end");
                scriptWriter.printfln("  def users(login)");
                scriptWriter.printfln("    login = {:project_member => 'member'}[login] || login.to_s");
                scriptWriter.printfln("    User.find_by_login(login)");
                scriptWriter.printfln("  end");
                scriptWriter.printfln("end");
                scriptWriter.printfln("ActiveRecord::Base.connection.begin_db_transaction");
                scriptWriter.printfln("begin");
                scriptWriter.printfln("  TwistTest.new('dynamic_code').dynamic_code");
                scriptWriter.printfln("ensure");
                scriptWriter.printfln("  ActiveRecord::Base.connection.commit_db_transaction");
                scriptWriter.printfln("end");
            }
        });

    }

    /**
     * Executes the code built by scriptBuilder as a top-level script
     *
     * @param scriptBuilder Callback to build your script
     * @return The result of evaluating the supplied script
     */
    public void executeWithBuilder(ScriptBuilder scriptBuilder) {
        StringWriter stringWriter = new StringWriter();
        ScriptWriter scriptWriter = new ScriptWriter(new PrintWriter(stringWriter));
        scriptBuilder.build(scriptWriter);
        executeRaw(stringWriter.toString());
    }

    /**
     * Executes the string as a ruby script as a top-level script
     *
     * @param script
     * @return The result of evaluating the supplied script
     */
    public void executeRaw(String script) {
        String url = this.getPlannerBaseUrl() + "/_eval";
        if (this.debugMode) {
            System.out.println("=========================================================================");
            System.out.println("Executing Ruby at " + url);
            System.out.println("=========================================================================");
            System.out.println(script);
            System.out.println("=========================================================================");
        }
        HttpClient client = new HttpClient();
        PostMethod method = new PostMethod(url);
        method.addParameter("scriptlet", script);
        try {
            client.executeMethod(method);
            if (this.debugMode) {
                System.out.println("--- response =========================================================================");
                System.out.println(method.getResponseBodyAsString());
            }
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    public void setDebugMode(boolean debugMode) {
        this.debugMode = debugMode;
    }

}
