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
 * Authors: Dodda Rampradeep and Deepak Lewis
 */
package net.sf.sahi.command;

import net.sf.sahi.request.HttpRequest;
import net.sf.sahi.response.HttpResponse;
import org.jmock.Mock;
import org.jmock.cglib.MockObjectTestCase;

import java.net.URL;
import java.io.File;

public class CommandInvokerTest extends MockObjectTestCase {
	private static final long serialVersionUID = -8519265344249609705L;
	private CommandInvoker commandInvoker;
    private final File HELPFILE = new File("help.txt");

    protected void setUp() throws Exception {
        commandInvoker = new CommandInvoker();
        HELPFILE.createNewFile();
    }

    protected void tearDown() throws Exception {
        HELPFILE.delete();
    }

    public void xtestExecuteRunsACommand() throws InterruptedException {
        assertTrue(HELPFILE.exists());
        HttpResponse response = commandInvoker.execute(prepareMockHttpRequest(getCommandPath("test.cmd"), true));
        String actualResponse = new String(response.data());
        assertEquals(CommandInvoker.SUCCESS, actualResponse);
        assertFalse(HELPFILE.exists());
    }

    public void xtestExecuteReturnsFailureForInvalidCommand() throws InterruptedException {
        HttpResponse response = commandInvoker.execute(prepareMockHttpRequest("invalid", true));
        String actualResponse = new String(response.data());
        assertEquals(CommandInvoker.FAILURE, actualResponse);
    }

    public void xtestExecuteRunsACommandInAsyncMode() throws InterruptedException {
        HttpResponse response = commandInvoker.execute(prepareMockHttpRequest(getCommandPath("test.cmd"), false));
        String actualResponse = new String(response.data());
        assertEquals(CommandInvoker.SUCCESS, actualResponse);
    }

    private HttpRequest prepareMockHttpRequest(String commandToExecute, boolean sync) {
        Mock mock = mock(HttpRequest.class);
        mock.expects(once()).method("getParameter").with(eq(RequestConstants.COMMAND)).will(returnValue(commandToExecute));
        mock.expects(once()).method("getParameter").with(eq(RequestConstants.SYNC)).will(returnValue(Boolean.toString(sync)));
        return (HttpRequest) mock.proxy();
    }

    public void testDummy(){
    }

    private String getCommandPath(String command) {
        URL resource = this.getClass().getResource(command);
        String commandToExecute = (null == resource) ? "invalid" : resource.getPath();
        if (commandToExecute.startsWith("/"))
            commandToExecute = commandToExecute.replaceFirst("/", "");
        return commandToExecute;
    }

}
