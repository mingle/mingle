package net.sf.sahi.test;

import junit.framework.TestCase;

import java.io.IOException;

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
public class SahiTestTest extends TestCase {

	private static final long serialVersionUID = 7669927478979181445L;

	@SuppressWarnings("unchecked")
	public void xtestProcess2() throws IOException, InterruptedException {
        Process p = null;
        java.util.Properties envVars = new java.util.Properties();
        Runtime r = Runtime.getRuntime();
        String OS = System.getProperty("os.name").toLowerCase();
        // System.out.println(OS);
        if (OS.indexOf("windows 9") > -1) {
            p = r.exec("command.com /c set");
        } else if ((OS.indexOf("nt") > -1)
                || (OS.indexOf("windows 2000") > -1)
                || (OS.indexOf("windows xp") > -1)) {
            // thanks to JuanFran for the xp fix!
            p = r.exec("cmd.exe /c set");
        } else {
            // our last hope, we assume Unix (thanks to H. Ware for the fix)
            p = r.exec("env");
        }
        java.io.BufferedReader br = new java.io.BufferedReader
                (new java.io.InputStreamReader(p.getInputStream()));
        String line;
        while ((line = br.readLine()) != null) {
            int idx = line.indexOf('=');
            String key = line.substring(0, idx);
            String value = line.substring(idx + 1);
            envVars.setProperty(key, value);

        }

        java.util.Enumeration keys = envVars.keys();
        String key;
        String[] props = new String[envVars.size() + 1];
        int i = 0;
        while (keys.hasMoreElements()) {
            key = keys.nextElement().toString();
            props[i] = key + "=" + envVars.getProperty(key);
            System.out.println(props[i]);
            i++;
        }
        props[i] = "MOZ_NO_REMOTE=1";
        Process process = Runtime.getRuntime().exec("C:/Program Files/Mozilla Firefox/firefox -profile \"D:\\my\\sahi\\ffprofiles\\sahi1\"", props);
//        Process process = Runtime.getRuntime().exec("C:/Program Files/Mozilla Firefox/firefox.exe", props);
        Thread.sleep(2000);
        System.out.println(p.toString());
        process.destroy();
//        Runtime.getRuntime().exec("C:/Program Files/Mozilla Firefox/firefox -profile \"d:/SahiFFProfileA\"", props);
//        Runtime.getRuntime().exec("C:/Program Files/Mozilla Firefox/firefox -profile \"d:/SahiFFProfileB\"", props);
    }


    public void xtestProcess() throws IOException, InterruptedException {
//        Properties properties = System.getProperties();
//
//        Object[] objects = System.getenv();
//
//        String[] props = new String[properties.size() + 1];
//        Enumeration enumeration = properties.keys();
//        int i = 0;
//        while (enumeration.hasMoreElements()) {
//            String key = (String) enumeration.nextElement();
//            String value = (String) properties.get(key);
//            props[i] = key+"="+value;
//            i++;
//        }
//
//        props[i] = "MOZ_NO_REMOTE=1";
//        for (int j = 0; j < props.length; j++) {
//            String prop = props[j];
//            System.out.println(prop);
//        }


        String[] props = new String[2];
        props[0] = "PATH=D:\\Java\\1.4\\jre\\bin;.;C:\\WINDOWS\\system32;C:\\WINDOWS;C:\\WINDOWS\\system32;C:\\WINDOWS;C:\\WINDOWS\\System32\\Wbem;D:\\putty\\;D:\\my\\bin;D:\\dev\\ant-1.6.2\\bin;D:\\Java\\1.5\\bin;;c:\\program files\\borland\\StarTeam SDK 2005 R2\\Lib;c:\\program files\\borland\\StarTeam SDK 2005 R2\\Bin;C:\\php;";
        props[1] = "MOZ_NO_REMOTE=1";

//        Object[] objects = System.getenv().entrySet().toArray();
//        String[] envp = new String[objects.length + 1];

//        int i;
//        String entry;
//        for (i = 0; i < objects.length; i++) {
//            envp[i] = objects[i].toString();
//        }
//        envp[i] = "MOZ_NO_REMOTE=1";

        System.getenv("PATH");
        Process p = Runtime.getRuntime().exec("MOZ_NO_REMOTE=1");
        Process p2 = Runtime.getRuntime().exec("C:\\Program Files\\Mozilla Firefox\\firefox.exe");
        Thread.sleep(2000);
        System.out.println(p.toString());
        p2.destroy();
    }
    
    public void test(){
    }

}
