package net.sf.sahi.command;

import junit.framework.TestCase;
import net.sf.sahi.command.MockResponder;

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
public class CustomResponseManagerTest extends TestCase {
	private static final long serialVersionUID = -8104865035753409420L;

	public void testGetCommand() {
        MockResponder mockResponder = new MockResponder();
        mockResponder.add(".*sahi[.]co[.]in.*", "net.sf.sahi.Test_test");
        String command = mockResponder.getCommand("http://www.sahi.co.in");
        assertEquals("net.sf.sahi.Test_test", command);
    }

}
