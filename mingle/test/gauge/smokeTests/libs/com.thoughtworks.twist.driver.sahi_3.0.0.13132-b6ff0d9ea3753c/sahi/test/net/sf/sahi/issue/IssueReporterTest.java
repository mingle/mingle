package net.sf.sahi.issue;

import org.jmock.Mock;
import org.jmock.MockObjectTestCase;

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
 * Date: Dec 8, 2006
 * Time: 5:57:45 PM
 */
public class IssueReporterTest extends MockObjectTestCase {
	private static final long serialVersionUID = 7349882941554985315L;
	private IssueReporter issueReporter;
    public void testCreateIssue()  {
        Mock mockIssueCreator = mock(IssueCreator.class);
        issueReporter = new IssueReporter("junit.suite");
        issueReporter.addIssueCreator((IssueCreator)mockIssueCreator.proxy());

        mockIssueCreator.expects(once()).method("login").withNoArguments();
        mockIssueCreator.expects(once()).method("createIssue").with(isA(Issue.class)).after("login");
        mockIssueCreator.expects(once()).method("logout").withNoArguments().after("createIssue");
        issueReporter.createIssue(new Issue("",""));
    }
}
