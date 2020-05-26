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

import java.net.SocketTimeoutException;
import java.util.ArrayList;
import java.util.List;

import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.NameValuePair;
import org.apache.http.client.HttpClient;
import org.apache.http.client.entity.UrlEncodedFormEntity;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.client.methods.HttpRequestBase;
import org.apache.http.message.BasicNameValuePair;
import org.apache.log4j.Logger;

import it.sauronsoftware.base64.Base64;

public class RequestThread extends Thread {

	private static Logger logger = Logger.getLogger(RequestThread.class);

    private final HttpClient httpClient;
    private final List<String> requesturis;
    private final int id;
    private final String mingle_host;
    private final String mingle_port;
    private final String mingle_user;
    private final String mingle_password;
    private int status2xx = 0, status3xx = 0, status4xx = 0, status5xx = 0, statusunknown=0;
    public RequestThread(String mingle_host, String mingle_port, String mingle_user, String mingle_password, HttpClient httpClient, List<String> requesturis, int id) {
        this.httpClient = httpClient;
        this.requesturis = requesturis;
        this.id = id;
        this.mingle_host = mingle_host;
        this.mingle_port = mingle_port;
        this.mingle_user = mingle_user;
        this.mingle_password = mingle_password;
    }
    
    public int getStatusCount(int code){
        switch (code){
            case  2:
                return status2xx;
            case  3:
                return status3xx;
            case  4:
                return status4xx;
            case  5:
                return status5xx;
            default:
            	return statusunknown;
        }
    }
    private void sendRequest(String requesturi){
        HttpResponse response = null;
        String[] requesturisplit;
        HttpRequestBase httprequest = null;
        try {
            String userpassword = this.mingle_user + ":"  + this.mingle_password;
            String encodedAuthorization = Base64.encode(userpassword);
            
            if (requesturi.indexOf("method=POST") == -1){
                if (requesturi.indexOf("method=GET") == -1){
                    httprequest = new HttpGet("http://" + this.mingle_host + ":" + this.mingle_port + requesturi);
                }else{
                    requesturisplit = requesturi.split(" ");
                    httprequest = new HttpGet("http://" + this.mingle_host + ":" + this.mingle_port + requesturisplit[0]);
                }
            
            }
            else{
                requesturisplit = requesturi.split(" ");
                String[] splitaction = requesturisplit[0].split("\\?");
                httprequest = new HttpPost("http://" + this.mingle_host + ":" + this.mingle_port + splitaction[0]);
                httprequest.addHeader("Content-Type","application/x-www-form-urlencoded");
                String params = requesturisplit[2];
                requesturisplit = params.substring(10,params.length()).split("&");
                String[] paramsplit;
                List<NameValuePair> nameValuePairs = new ArrayList<NameValuePair>(requesturisplit.length+1);
                paramsplit = splitaction[1].split("=");
                nameValuePairs.add(new BasicNameValuePair(paramsplit[0],paramsplit[1]));
                for(int i=0;i < requesturisplit.length; i++){
                    paramsplit = requesturisplit[i].split("=");
                    nameValuePairs.add(new BasicNameValuePair(paramsplit[0],paramsplit[1]));
                }
                ((HttpPost)httprequest).setEntity(new UrlEncodedFormEntity(nameValuePairs));
            }
            
            httprequest.addHeader("Authorization","Basic "+encodedAuthorization);
            response = httpClient.execute(httprequest);
            
            logger.info(id + " : " + String.valueOf(response.getStatusLine().getStatusCode()));
            if (response.getStatusLine().getStatusCode() >= 500){
                logger.error( "=====================\n  Error : " + requesturi);
            }
            HttpEntity entity = response.getEntity();
            if (entity != null) {
                entity.consumeContent();
            }
            if (response != null){
                int rcode = response.getStatusLine().getStatusCode();
                if ( (rcode < 300) && (rcode >= 200) )
                    ++status2xx;
                else if ( (rcode < 400) && (rcode >= 300) )
                    ++status3xx;
                else if ( (rcode < 500) && (rcode >= 400) )
                    ++status4xx;
                else if ( (rcode < 600) && (rcode >= 500) )
                    ++status5xx;
                else
                    ++statusunknown;
            }
        } catch (SocketTimeoutException e){
            ++statusunknown;
        }catch (Exception e) {
            if (httprequest != null){
                httprequest.abort();
            }
            if (response != null){
            	System.out.println(id + " - error code " +  response.getStatusLine().toString());
            }
        }finally {
            httprequest.abort();
        }
    }
    /**
     * Executes the GetMethod and prints some status information.
     */
    @Override
    public void run() {
        try{
            while (true){
                sendRequest(requesturis.get((int)(Math.random()*(requesturis.size()))));
                Thread.sleep(10000);
            }
        } catch (InterruptedException e){
            // Parent Threads need to stop it
        } catch (Exception e){
            
        }
    }
}
