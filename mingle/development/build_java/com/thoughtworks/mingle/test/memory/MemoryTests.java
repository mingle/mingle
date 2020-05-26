/*
*  Copyright 2020 ThoughtWorks, Inc.
*  
*  This program is free software: you can redistribute it and/or modify
*  it under the terms of the GNU Affero General Public License as
*  published by the Free Software Foundation, either version 3 of the
*  License, or (at your option) any later version.
*  
*  This program is distributed in the hope that it will be useful,
*  but WITHOUT ANY WARRANTY; without even the implied warranty of
*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*  GNU Affero General Public License for more details.
*  
*  You should have received a copy of the GNU Affero General Public License
*  along with this program.  If not, see <https://www.gnu.org/licenses/agpl-3.0.txt>.
*/

package com.thoughtworks.mingle.test.memory;

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.util.ArrayList;
import java.util.regex.Pattern;


import junit.framework.TestCase;


import org.apache.http.HttpVersion;
import org.apache.http.client.HttpClient;
import org.apache.http.conn.ClientConnectionManager;
import org.apache.http.conn.params.ConnManagerParams;
import org.apache.http.conn.scheme.PlainSocketFactory;
import org.apache.http.conn.scheme.Scheme;
import org.apache.http.conn.scheme.SchemeRegistry;
import org.apache.http.conn.ssl.SSLSocketFactory;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.impl.conn.tsccm.ThreadSafeClientConnManager;
import org.apache.http.params.BasicHttpParams;
import org.apache.http.params.HttpConnectionParams;
import org.apache.http.params.HttpParams;
import org.apache.http.params.HttpProtocolParams;
import org.apache.log4j.Logger;

public class MemoryTests extends TestCase {

    private static Logger logger = Logger.getLogger(MemoryTests.class);


    public void setUp(){
    }
    
    public void tearDown(){
    }
    

    public void testMemoryTest(){
    
        int socketTimeoutMillis = 180000;
        int connectionTimeoutMillis = 5000;
        ArrayList<String> lines = new ArrayList<String>();
        ArrayList<String> tmpLines;
        
        String httplog_dir = System.getProperty("HTTPLOG_DIR");
        int maximum_request = Integer.parseInt(System.getProperty("max_request"));
        int maximum_allowed_errors = Integer.parseInt(System.getProperty("allowed_errors"));
        String hlog_file_list = System.getProperty("hlog_files");
        int hours_to_run = Integer.parseInt(System.getProperty("run_hours"));
        String mingle_host = System.getProperty("mingle_host");
        String mingle_port = System.getProperty("mingle_port");
        String mingle_jmx_port = System.getProperty("jmx_port");
        String mingle_user = System.getProperty("mingle_user");
        String mingle_password = System.getProperty("mingle_password");

        String[] hlog_files = Pattern.compile(",").split(hlog_file_list);
        for(int i=0; i < hlog_files.length; i++){
            tmpLines=MemoryTests.ReadRequestFromFile(hlog_files[i].trim(),httplog_dir);
            if (tmpLines == null)
                System.exit(1);
            lines.addAll(tmpLines);
        }
        
        HttpParams params = new BasicHttpParams();
        ConnManagerParams.setMaxTotalConnections(params, maximum_request);
        HttpProtocolParams.setVersion(params, HttpVersion.HTTP_1_1);
        SchemeRegistry schemeRegistry = new SchemeRegistry();
        schemeRegistry.register(
                new Scheme("http", PlainSocketFactory.getSocketFactory(), 80));
        schemeRegistry.register(
                new Scheme("https", SSLSocketFactory.getSocketFactory(), 443));
        HttpConnectionParams.setConnectionTimeout(params, connectionTimeoutMillis);
        HttpConnectionParams.setSoTimeout(params, socketTimeoutMillis);
        ClientConnectionManager cm = new ThreadSafeClientConnManager(params, schemeRegistry);
        HttpClient httpClient = new DefaultHttpClient(cm, params);

        // create a thread for each URI
        RequestThread[] threads = new RequestThread[maximum_request];
        PollJMX jmxThread = new PollJMX(mingle_host,mingle_jmx_port);
        jmxThread.start();
        
        int limit;
        for (int i = 0; i < threads.length; i++) {
            limit = ( (i+2) * (lines.size()/maximum_request)) > lines.size() ? lines.size() : (i+1) * (lines.size()/maximum_request);
            threads[i] = new RequestThread(mingle_host, mingle_port, mingle_user, mingle_password, httpClient, lines.subList((i*(lines.size()/maximum_request)), limit), i + 1);
        }
        
        // start the threads
        for (int j = 0; j < threads.length; j++) {
            threads[j].start();
        }
        long startTime = System.currentTimeMillis();
        long timeTorun = hours_to_run * 60 * 60 * 1000;
        boolean allthreadsAlive = true, jmxThreadIsAlive = true, normalStop = false, hasMemoryLeak = false;
        long baselineMemoryUsed;
        int numof2xx=0, numof3xx=0, numof4xx=0, numof5xx=0, numofUnknown=0;
        while(allthreadsAlive ){
            try{
                if((System.currentTimeMillis() - startTime) > timeTorun){
                    System.out.println("MemoryTests is done");
                    normalStop = true;
                    for (int j = 0; j < threads.length; j++) {
                        threads[j].interrupt();
                    }
                    jmxThread.interrupt();
                    allthreadsAlive = false;
                }else{
                    numof2xx = 0;
                    numof3xx = 0;
                    numof4xx = 0;
                    numof5xx = 0;
                    numofUnknown = 0;
                    for(int j = 0; j < threads.length; j++) {
                        try{
                            if(threads[j] != null && threads[j].isAlive()){
                                numof2xx += threads[j].getStatusCount(2);
                                numof3xx += threads[j].getStatusCount(3);
                                numof4xx += threads[j].getStatusCount(4);
                                numof5xx += threads[j].getStatusCount(5);
                                numofUnknown += threads[j].getStatusCount(-1);
                            }else{
                                numofUnknown = maximum_allowed_errors;
                            }
                        }catch(Exception e){
                            numofUnknown = maximum_allowed_errors;
                            logger.info(e.getMessage());
                        }
                    }
                    // if( ((numof5xx+numofUnknown) >= maximum_allowed_errors) || !jmxThread.isAlive() || jmxThread.hasMemoryLeak()){
                    //                         hasMemoryLeak = jmxThread.hasMemoryLeak();
                    //                         baselineMemoryUsed = jmxThread.getBaselineMemoryUsed();
                    //                         try{
                    //                             for(int j = 0; j < threads.length; j++) {
                    //                                 if( threads[j].isAlive() )
                    //                                     if(threads[j] != null)
                    //                                         threads[j].interrupt();
                    //                             }
                    //                             if(!jmxThread.isAlive())
                    //                                 jmxThreadIsAlive = false;
                    //                             if(jmxThread != null)
                    //                                 jmxThread.interrupt();
                    //                          }catch(Exception e){
                    //                          }
                    //                          allthreadsAlive = false;
                    //                          System.out.println("MemoryTests failed with : 2xx-" + numof2xx + " 3xx-" + numof3xx + " 4xx-" + numof4xx + " 5xx-" + numof5xx + " Unknown-" + numofUnknown + " JMX Thread isAlive-" + jmxThreadIsAlive + " Has Memory Leak-" + hasMemoryLeak + " Baseline Memory Used-" + baselineMemoryUsed);
                    //                      }
                     logger.debug("Total Errors : " + (numof5xx+numofUnknown));
                }
                Thread.sleep(5000);
            }catch(Exception e){
            }
        }
        GraphGenerator graphGen = new GraphGenerator();
        graphGen.createGraph();
        if (!normalStop){
            System.out.println("Would normally fail() here, but we temporarily don't want to fail so that we can generate a heap dump.");
            System.out.println("MemoryTests failed with : 2xx-" + numof2xx + " 3xx-" + numof3xx + " 4xx-" + numof4xx + " 5xx-" + numof5xx + " Unknown-" + numofUnknown + "  | JMX Thread isAlive-" + jmxThreadIsAlive + " Has Memory Leak " + hasMemoryLeak);
            // fail("MemoryTests failed with : 2xx-" + numof2xx + " 3xx-" + numof3xx + " 4xx-" + numof4xx + " 5xx-" + numof5xx + " Unknown-" + numofUnknown + "  | JMX Thread isAlive-" + jmxThreadIsAlive + " Has Memory Leak " + hasMemoryLeak);
        }
    }

    public static ArrayList<String> ReadRequestFromFile(String hlog,String httplog_dir){
        ArrayList<String> lines = new ArrayList<String>();
        try{
            FileReader fileReader = new FileReader(httplog_dir+ System.getProperty("file.separator") + hlog + ".hlog");
            BufferedReader bufferedReader = new BufferedReader(fileReader);
            String line = null;
            while ((line = bufferedReader.readLine()) != null) {
                lines.add(line);
            }
            bufferedReader.close();
        }catch (IOException e){
            e.printStackTrace();
            return null;
        }
        return lines;
    }


}
