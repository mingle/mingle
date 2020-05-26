package net.sf.sahi.util;

import net.sf.sahi.config.Configuration;
import junit.framework.TestCase;

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
public class OSUtilsTest extends TestCase {
	private static final long serialVersionUID = -844205436414642224L;	
	
	@Override
	protected void setUp() throws Exception {
		Configuration.init();
		super.setUp();
	}
	
	public void testIdentifyOS() throws Exception {
		if(Utils.isWindows())
		assertEquals("xp", OSUtils.identifyOS());
	}
	
	public void testGetPIDListCommmand() throws Exception {
		if(Utils.isWindows())
		assertEquals("tasklist /FI \"IMAGENAME eq $imageName\" /NH /FO TABLE",OSUtils.getPIDListCommand());
	} 
	
	public void testGetPIDKillCommand() throws Exception {
		if(Utils.isWindows())
		assertEquals("taskkill /F /PID $pid",OSUtils.getPIDKillCommand());
	}
	
	public void testGetPIDListColumnNo() throws Exception {
		assertEquals(2,OSUtils.getPIDListColumnNo());
	}
}
