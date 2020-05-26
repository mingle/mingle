package net.sf.sahi.command;

import junit.framework.TestCase;

import net.sf.sahi.request.HttpRequest;

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
public class CommandExecuterTest extends TestCase {
	private static final long serialVersionUID = -918331594375717865L;
	static boolean called = false;

	public void testMethodCalled() throws Exception {
		final HttpRequest httpRequest = null;
		new CommandExecuter("net.sf.sahi.command.TestClass_act", httpRequest, false).execute();
		assertTrue(called);
	}

	public void testMethodCalledWithoutClassFQN() throws Exception {
		final HttpRequest httpRequest = null;
		new CommandExecuter("TestClass_act", httpRequest, false).execute();
		assertTrue(called);
	}

	public void tearDown() {
		called = false;
	}

	public void testCommandClass() throws Exception {
		final HttpRequest httpRequest = null;
		assertEquals("com.domain.TestClass", new CommandExecuter("com.domain.TestClass_act", httpRequest, false).getCommandClass());
		assertEquals("act", new CommandExecuter("com.domain.TestClass_act", httpRequest, false).getCommandMethod());
		assertEquals("net.sf.sahi.command.TestClass", new CommandExecuter("TestClass_act", httpRequest, false).getCommandClass());
		assertEquals("act", new CommandExecuter("TestClass_act", httpRequest, false).getCommandMethod());
	}
}
