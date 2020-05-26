package net.sf.sahi.request;

import java.io.UnsupportedEncodingException;
import java.net.URLDecoder;
import java.util.List;

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
public class HttpRequestTest extends TestCase {

	private static final long serialVersionUID = 7198890274763001829L;

//	public void testRebuildCookies() {
//		Map<String, String> cookies = new LinkedHashMap<String, String>();
//		cookies.put("_session_id", "cookieVal");
//		assertEquals("_session_id=cookieVal", HttpRequest.rebuildCookies(cookies));
//		cookies.put("sahisid", "cookieVal2");
//		assertEquals("_session_id=cookieVal; sahisid=cookieVal2", HttpRequest.rebuildCookies(cookies));
//		cookies.put("cookieName3", "cookieVal3");
//		assertEquals("_session_id=cookieVal; sahisid=cookieVal2; cookieName3=cookieVal3", HttpRequest.rebuildCookies(cookies));
//	}


    public void testUnicode() throws UnsupportedEncodingException {
       URLDecoder.decode("abc", "sadalkdjlaksjdfl");
    }

    public void testSetUri(){
        assertEquals("/login?service=http://www.hostname.com/landing",
                new HttpRequest().stripHostName("/login?service=http://www.hostname.com/landing", "www.hostname.com", false));
        assertEquals("/login?service=http://www.hostname.com/landing",
                new HttpRequest().stripHostName("http://www.hostname.com/login?service=http://www.hostname.com/landing",
                        "www.hostname.com", false));
        assertEquals("/netdirector/",
                new HttpRequest().stripHostName("http://localhost:8080/netdirector/", "localhost", false));
        assertEquals("/netdirector/",
                new HttpRequest().stripHostName("/netdirector/", "localhost", false));
        assertEquals("/netdirector/?service=http://localhost:8080/landing",
                new HttpRequest().stripHostName("http://localhost:8080/netdirector/?service=http://localhost:8080/landing", "localhost", false));
    }
    
    public void testHandleSahiCookie() throws Exception {
		checkCookie("a=b; sahisid=123; c=d", "a=b; c=d");
		checkCookie("a=b; sahisid=123;", "a=b");
		checkCookie("sahisid=123; c=d", "c=d");
		checkCookie("a=b; sahisid=123", "a=b");
		checkCookie("a=b; e=f; sahisid=123; c=d; g=h", "a=b; e=f; c=d; g=h");
	}


	private void checkCookie(String before, String after) {
		HttpRequest request = new HttpRequest();
		request.setHeader("Cookie", before);
		request.handleSahiCookies();
		assertEquals("123", request.sahiCookie());
		assertEquals(after, request.headers().getLastHeader("Cookie"));
	}
	
	public void testCheckMultiCookieHeader() throws Exception {
		HttpRequest request = new HttpRequest();
		request.addHeader("Cookie", "sahisid=1231212; a=b; c=d");
		request.addHeader("Cookie", "e=f");
		request.handleSahiCookies();
		assertEquals("1231212", request.sahiCookie());
		final List<String> headers = request.headers().getHeaders("Cookie");
		assertEquals("a=b; c=d", headers.get(0));
		assertEquals("e=f", headers.get(1));
	}
	
	public void testCheckMultiCookieHeaderIgnoresBlank() throws Exception {
		HttpRequest request = new HttpRequest();
		request.addHeader("Cookie", "sahisid=1231212");
		request.addHeader("Cookie", "e=f");
		request.handleSahiCookies();
		assertEquals("1231212", request.sahiCookie());
		final List<String> headers = request.headers().getHeaders("Cookie");
		assertEquals(1, headers.size());
		assertEquals("e=f", headers.get(0));
	}
}
