package net.sf.sahi.ant;

import org.apache.tools.ant.BuildException;
import org.apache.tools.ant.BuildFileTest;

/**
 * Sahi - Web Automation and Test Tool
 * 
 * Copyright  2006  V Narayan Raman
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
/**
 * User: dlewis
 * Date: Dec 6, 2006
 * Time: 11:12:39 AM
 */
public class RunSahiTaskTest extends BuildFileTest {
	private static final long serialVersionUID = 3846373869350296304L;

	public RunSahiTaskTest(String s) {
        super(s);
    }


    protected void setUp() throws Exception {
        configureProject("antTest.xml");
    }

    public void testSahiWithoutNested() {
        executeTarget("testSahiWithoutNested");
    }

    public void testSahiWithNestedReport() {
        executeTarget("testSahiWithNestedReport");
    }

    public void testReportWithInvalidType() {
        try {
            executeTarget("testReportWithInvalidType");
            fail("Should throw BuildException for invalid type attribute");
        } catch (BuildException e) {
            assertTrue(true);
        }
    }

    public void testSahiWithNestedCreateIssue() {
        executeTarget("testSahiWithNestedCreateIssue");
    }

    public void testCreateIssueWithInvalidTool() {
        try {
            executeTarget("testCreateIssueWithInvalidTool");
            fail("Should throw BuildException for invalid tool attribute");
        } catch (BuildException e) {
            assertTrue(true);
        }
    }

    public void testSahiWithNestedCreateIssueAndReport() {
        executeTarget("testSahiWithNestedCreateIssueAndReport");
    }
}
