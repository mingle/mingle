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

package com.thoughtworks.mingle.planner.smokeTest.util;

import org.joda.time.DateTime;
import org.joda.time.Days;
import org.joda.time.format.DateTimeFormat;
import org.joda.time.format.DateTimeFormatter;

public class DateFormatter {

    private final DateTimeFormatter humanFormat = DateTimeFormat.forPattern("d MMM yyyy");

    public String toHumanFormat(String aDateString) {
        return humanFormat.print(humanFormat.parseDateTime(aDateString));
    }

    public String getFutureDateAsStringAfterInHumanFormat(String aStartDate, int daysDifference) throws Exception {
        return humanFormat.print(humanFormat.parseDateTime(aStartDate).plusDays(daysDifference));
    }

    // public String getWeeksViewFormat(String startDateOfWeek) throws Exception
    // {
    // String endDateOfThisWeek =
    // getFutureDateAsStringAfterInHumanFormat(startDateOfWeek, 6);
    // return toHumanFormat(startDateOfWeek) + " - " + endDateOfThisWeek;
    // }

    public String getMonthViewFormat(String aDateString) throws Exception {
        DateTime date = humanFormat.parseDateTime(aDateString);
        DateTime.Property month = date.monthOfYear();
        DateTime.Property year = date.year();
        return month.getAsText() + " " + year.getAsText();
    }

    public int getDayOfMonth(String aDateString) throws Exception {
        DateTime date = humanFormat.parseDateTime(aDateString);
        return date.getDayOfMonth();
    }

    public int getDaysDifference(String startDateString, String endDateString) throws Exception {
        DateTime startDate = humanFormat.parseDateTime(startDateString);
        DateTime endDate = humanFormat.parseDateTime(endDateString);
        Days days = Days.daysBetween(startDate, endDate);
        return days.getDays();
    }

    public int getDayOfWeek(String aDateString) throws Exception {
        DateTime date = humanFormat.parseDateTime(aDateString);
        return date.getDayOfWeek();
    }

    public String getWeeksViewFormat(String dateString) throws Exception {
        DateTime date = humanFormat.parseDateTime(dateString);
        DateTime weekBeginningDate = date.dayOfWeek().withMinimumValue();
        DateTime weekEndingDate = date.dayOfWeek().withMaximumValue();
        return weekBeginningDate.toString(humanFormat) + " - " + weekEndingDate.toString(humanFormat);
    }

}
