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

import java.io.*;
import java.util.*;
import java.text.*;
import org.jfree.data.xy.XYSeries;
import org.jfree.data.xy.XYDataset;
import org.jfree.data.xy.XYSeriesCollection;
import org.jfree.chart.ChartFactory;
import org.jfree.chart.JFreeChart;
import org.jfree.chart.plot.PlotOrientation;
import org.jfree.chart.ChartUtilities;
import org.jfree.data.time.TimeSeries;
import org.jfree.data.time.RegularTimePeriod;
import org.jfree.data.time.Second;
import org.jfree.data.time.Day;
import org.jfree.data.time.TimeSeriesCollection;
import java.text.DateFormat;


public class MemoryTestGraphGenerator{

	public static void main(String args[]){

		try{

			MemoryTestGraphGenerator.generateGraph("tmp/heap_max.jpg",1);
			MemoryTestGraphGenerator.generateGraph("tmp/heap_used.jpg",2);
			MemoryTestGraphGenerator.generateGraph("tmp/heap_committed.jpg",3);
			MemoryTestGraphGenerator.generateGraph("tmp/gcConc_collection_time.jpg",4);
			MemoryTestGraphGenerator.generateGraph("tmp/gcConc_collection_count.jpg",5);
			MemoryTestGraphGenerator.generateGraph("tmp/gcPn_collection_time.jpg",6);
			MemoryTestGraphGenerator.generateGraph("tmp/gcPn_collection_count.jpg",7);
			MemoryTestGraphGenerator.generateHTML("tmp/memory_graph.html");

		} catch (Exception ex){
				ex.printStackTrace();
		}
	}
	
	public static void generateHTML(String filename){
		try{
			FileWriter fw = new FileWriter(new File(filename));
			fw.write("</p></p><img src=\"heap_committed.jpg\"/></p>\n");
			fw.write("<img src=\"heap_used.jpg\"/></p>\n");
			fw.write("<img src=\"heap_max.jpg\"/></p>\n");
			fw.write("<img src=\"gcConc_collection_time.jpg\"/></p>\n");
			fw.write("<img src=\"gcConc_collection_count.jpg\"/></p>\n");
			fw.write("<img src=\"gcPn_collection_time.jpg\"/></p>\n");
			fw.write("<img src=\"gcPn_collection_count.jpg\"/></p>\n");
			fw.close();
		} catch (Exception ex){
			ex.printStackTrace();
		}
	}

	public static void generateGraph(String filename, int graphType) {
		try{
			XYDataset memoryData = new TimeSeriesCollection(MemoryTestGraphGenerator.getSeries(graphType));
			JFreeChart memoryChart = null;
			switch (graphType){
				case 1:
                			memoryChart = ChartFactory.createTimeSeriesChart(
                        		"Heap Max",
                        		"Date",
                        		"Heap Max (in MBytes)",
                        		memoryData,
                        		true,
                        		true,
                        		false);
					break;
				case 2:
                			memoryChart = ChartFactory.createTimeSeriesChart(
                        		"Heap Used",
                        		"Date",
                        		"Heap Used (in MBytes)",
                        		memoryData,
                        		true,
                        		true,
                        		false);
					break;
				case 3:
                			memoryChart = ChartFactory.createTimeSeriesChart(
                        		"Heap Committed",
                        		"Date",
                        		"Heap Committed (in MBytes)",
                        		memoryData,
                        		true,
                        		true,
                        		false);
					break;
				case 4:
                			memoryChart = ChartFactory.createTimeSeriesChart(
                        		"GC Conc Collection Time",
                        		"Date",
                        		"GC Conc Collection Time",
                        		memoryData,
                        		true,
                        		true,
                        		false);
					break;
				case 5:
                			memoryChart = ChartFactory.createTimeSeriesChart(
                        		"GC Conc Collection Count",
                        		"Date",
                        		"GC Conc Collection Count",
                        		memoryData,
                        		true,
                        		true,
                        		false);
					break;
				case 6:
                			memoryChart = ChartFactory.createTimeSeriesChart(
                        		"GC Pn Collection Time",
                        		"Date",
                        		"GC Pn Collection Time",
                        		memoryData,
                        		true,
                        		true,
                        		false);
					break;
				case 7:
                			memoryChart = ChartFactory.createTimeSeriesChart(
                        		"GC Pn Collection Count",
                        		"Date",
                        		"GC Pn Collection Count",
                        		memoryData,
                        		true,
                        		true,
                        		false);
					break;
				}	
			if (memoryChart != null){
                		ChartUtilities.saveChartAsJPEG(new File(filename), memoryChart, 500, 300);
			} else {
				System.out.println("Cannot generate " + filename + " graph.");
			}

                } catch (Exception ex){
                        ex.printStackTrace();
                }
	}
	
	public static TimeSeries getSeries(int graphType) throws Exception {
	
		String graphDesc = null;

		switch (graphType){
			case 1:
				graphDesc = new String("Heap Max");
				break;
			case 2:
				graphDesc = new String("Heap Used");
				break;
			case 3:
				graphDesc = new String("Heap Committed");
				break;
			case 4:
				graphDesc = new String("gcConc Collection Time");
				break;
			case 5:
				graphDesc = new String("gcConc Collection Count");
				break;
			case 6:
				graphDesc = new String("gcPn Collection Time");
				break;
			case 7:
				graphDesc = new String("gcPn Collection Count");
				break;
			default:
				graphDesc = new String("Unknown");
				break;
		}

		DateFormat df = new SimpleDateFormat("EEE MMM dd hh:mm:ss Z yyyy");
		TimeSeries series = new TimeSeries(graphDesc, Second.class);


                try{
                        File file = new File("tmp/memorytest.csv"); 
                        StringBuffer contents = new StringBuffer();
                        BufferedReader reader  = null;

                        reader = new BufferedReader(new FileReader(file));
			int gData;
                        String text = null;
			String[] tmpDatas;
                        while ((text = reader.readLine()) != null)
                        {
				tmpDatas = text.split(",");	
			switch (graphType){
				case 1 :
					gData = (Integer.valueOf(tmpDatas[graphType])/1024)/1024;
					break;
				case 2 :
					gData = (Integer.valueOf(tmpDatas[graphType])/1024)/1024;
					break;
				case 3 :
					gData = (Integer.valueOf(tmpDatas[graphType])/1024)/1024;
					break;
				default:
					gData = Integer.valueOf(tmpDatas[graphType]);
					break;
			}
			
				series.addOrUpdate(new Second(df.parse(tmpDatas[0])),gData);
				tmpDatas = null;
                        }
			reader.close();
				
                }catch (Exception e){
                        e.printStackTrace();
                }  

                return series;
        }

}
