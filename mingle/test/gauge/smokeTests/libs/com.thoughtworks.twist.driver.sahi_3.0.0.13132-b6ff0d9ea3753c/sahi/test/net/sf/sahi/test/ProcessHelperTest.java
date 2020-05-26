package net.sf.sahi.test;

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
public class ProcessHelperTest extends TestCase {
	private static final long serialVersionUID = -268318881994670816L;
	public void xtestFirefoxKill() throws Exception {
		for (int i = 0; i < 100; i++) {
			String cmd = "\"C:\\Program Files\\Mozilla Firefox\\firefox.exe\" -profile \"D:/sahi_v2/browser/ff/profiles/sahi0\"";
			ProcessHelper ph = new ProcessHelper(cmd, "firefox.exe");
			ph.execute();
			ph.kill();
			Thread.sleep(1000);
		}
	}

	/**
	 *
	 */
	public void xtestGetPIDs() {
		ProcessHelper ph = new ProcessHelper(
				"\"C:\\Program Files\\Mozilla Firefox\\firefox.exe\" -profile \"D:/sahi_v2/browser/ff/profiles/sahi0\"", "firefox.exe");
		ph.getPIDs();
	}
	public void testDummy(){
		assertEquals("", "");
	}
}
