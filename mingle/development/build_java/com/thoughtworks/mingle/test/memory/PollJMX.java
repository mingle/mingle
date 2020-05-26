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

import java.io.FileOutputStream;
import java.io.PrintStream;
import java.util.Calendar;
import java.util.Random;

import javax.management.MBeanServerConnection;
import javax.management.ObjectName;
import javax.management.openmbean.CompositeData;
import javax.management.remote.JMXConnector;
import javax.management.remote.JMXConnectorFactory;
import javax.management.remote.JMXServiceURL;

public class PollJMX extends Thread {
    
    private final String host;
    private final String port;
    private final long[] fiveMinutes;
    private int fiveMinIndex;
    private int runCounts;
    private long baselinememoryused;
    private boolean potentialMemoryLeak;
    
    public PollJMX(String host, String port){
        this.host = host;
        this.port = port;
        this.fiveMinutes = new long[300];
        this.fiveMinIndex = 0;
        this.runCounts = 0;
        this.baselinememoryused = -1;
        this.potentialMemoryLeak = false;
    }
    
    public long getBaselineMemoryUsed(){
        return baselinememoryused;
    }

    public boolean hasMemoryLeak(){
        return this.potentialMemoryLeak;
    }

    public void run(){
        FileOutputStream fout = null;
        PrintStream pstr = null;
        try{
            try{
                fout = new FileOutputStream("tmp/memorytest.csv");
                pstr = new PrintStream(fout);
                JMXServiceURL url = new JMXServiceURL("service:jmx:rmi:///jndi/rmi://" + this.host + ":" + this.port + "/jmxrmi");
                JMXConnector conn = JMXConnectorFactory.connect(url);
                MBeanServerConnection server = conn.getMBeanServerConnection();
                ObjectName concurrentMarkSweep, parNew, memory;
                CompositeData heapMemoryUsage;
                long heapMemoryUsed;
                long tenSecondsLowest = 0;
                int tenSecIndex = 0;
                int curMemoryUsedCheck = 0;
                while (true){
                    concurrentMarkSweep = new ObjectName("java.lang:type=GarbageCollector,name=ConcurrentMarkSweep");
                    parNew = new ObjectName("java.lang:type=GarbageCollector,name=ParNew");
                    memory =  new ObjectName("java.lang:type=Memory");
                    heapMemoryUsage = (CompositeData) server.getAttribute(memory,"HeapMemoryUsage");
                    heapMemoryUsed = ((Long)heapMemoryUsage.get("used")).longValue();
                    pstr.println(Calendar.getInstance().getTime()+","+heapMemoryUsage.get("max")+","+ heapMemoryUsed +","+heapMemoryUsage.get("committed")
                        +","+server.getAttribute(concurrentMarkSweep, "CollectionTime")+","+server.getAttribute(concurrentMarkSweep, "CollectionCount")
                        +","+server.getAttribute(parNew, "CollectionTime")+","+server.getAttribute(parNew, "CollectionCount"));
                    Thread.sleep(10000);
                    if (runCounts >= 540 ){
                        if (tenSecondsLowest == 0){
                            tenSecondsLowest = heapMemoryUsed;
                        }else{
                           if ( heapMemoryUsed < tenSecondsLowest ){
                               tenSecondsLowest = heapMemoryUsed;
                           }
                        }
                        if (tenSecIndex >= 29 ){
                            if ((baselinememoryused > -1) && (!this.potentialMemoryLeak)){
                                if (tenSecondsLowest > baselinememoryused){
                                    if (curMemoryUsedCheck <=10){
                                        ++curMemoryUsedCheck;
                                    }else{
                                        this.potentialMemoryLeak = true;
                                    }
                                }else{
                                    curMemoryUsedCheck = 0;
                                }
                            }
                            fiveMinutes[this.fiveMinIndex++] = tenSecondsLowest;
                            tenSecondsLowest = 0;
                            tenSecIndex = 0;
                        }else{
                            ++tenSecIndex;
                        }
                        if (baselinememoryused < 0){
                            if (fiveMinIndex >= 12){
                		FileOutputStream tmp_fout = new FileOutputStream("tmp/tmp_memorytest_baseline.csv");
                		PrintStream tmp_pstr = new PrintStream(tmp_fout);
                                for(int index=0; index < 12; index++){
                    		    tmp_pstr.println(fiveMinutes[index]);
                                    baselinememoryused += fiveMinutes[index]; 
                                }
                                baselinememoryused = baselinememoryused / 12;
                                tmp_pstr.println(baselinememoryused);
				tmp_pstr.close();
				tmp_fout.close();
                             }
                         }
                    }
                    concurrentMarkSweep = null;
                    parNew = null;
                    memory = null;
                    heapMemoryUsage = null;
                    ++runCounts;
                }
            }catch(InterruptedException e){
                // Parent Threads need to stop it
            }finally{
                if(pstr != null)
                    pstr.close();
                if(fout != null)
                    fout.close();
                }
        }catch(Exception e){
            e.printStackTrace();
        }
    }
    

}
