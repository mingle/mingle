package net.sf.sahi.session;

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
public class SessionTest extends TestCase {
	private static final long serialVersionUID = 5444089813420833709L;

	Session session = new Session("");
    public void testRemoveVariables(){
        session.setVariable("condn1", "1");
        session.setVariable("condn2", "2");
        session.setVariable("condn3", "3");

        assertEquals("1", session.getVariable("condn1"));
        assertEquals("2", session.getVariable("condn2"));
        assertEquals("3", session.getVariable("condn3"));

        session.removeVariables("condn.*");

        assertEquals(null, session.getVariable("condn1"));
        assertEquals(null, session.getVariable("condn2"));
        assertEquals(null, session.getVariable("condn3"));

    }
    
    public void testSessionState(){
    	session.setIsRecording(true);
    	assertTrue(session.isRecording());
    	session.setIsRecording(false);
    	assertFalse(session.isRecording());
    }
    
    public void testRemoveInactiveDoesNotRemoveRecordingSessions() throws Exception {
		session.setIsPlaying(true);
		assertEquals(Session.playbackInactiveTimeout, session.getInactiveTimeout());
		session.setIsPlaying(false);
		assertEquals(Session.recorderInactiveTimeout, session.getInactiveTimeout());
		
	}
}
