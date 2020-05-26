package net.sf.sahi;

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
public class ProxyTest extends TestCase {
	private static final long serialVersionUID = -6668205255083091407L;

	public void testCreateAndStartProxyFromJava() throws Exception {
		Configuration.init();
		final Proxy proxy = new Proxy();
		assertFalse(proxy.isRunning());

		try {
			proxy.start(true);
			Thread.sleep(1500);
			assertTrue(proxy.isRunning());
		} catch (Exception e) {
			fail(e.getMessage());
		} finally {
			proxy.stop();
			assertFalse(proxy.isRunning());
		}
	}
}
