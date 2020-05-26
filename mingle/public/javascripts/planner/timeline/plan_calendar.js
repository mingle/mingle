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
Timeline.DateUtils = {
  addDays: function(date, days) {
    var newDate = new Date(date.getTime());
    newDate.setDate(date.getDate() + days);
    return newDate;
  },
  
  differenceInDays: function(startDate, endDate) {
    return Math.ceil((this.toUTC(endDate) - this.toUTC(startDate))/Timeline.DateUtils.MILLISECONDS_PER_DAY);
  },
  
  toUTC: function(date) {
    return Date.UTC(date.getFullYear(), date.getMonth(), date.getDate());
  },
  
  shortMonthName: function(index) {
    return Timeline.DateUtils.SHORT_MONTHS[index];
  },

  fullMonthName: function(index) {
    return Timeline.DateUtils.FULL_MONTHS[index];
  },
  
  lastDayOfWeek: function(date) {
    if (date.getDay() === 0) {
      return date;
    }
    return this.addDays(date, 7 - date.getDay());
  },
  
  lastDayOfMonth: function(date) {
    var day = new Date(date.getTime());
    day.setDate(this.daysInMonth(date));
    return day;
  },
  
  lastDayOfYear: function(date) {
    var day = new Date(date.getTime());
    day.setMonth(11);
    day.setDate(31);
    return day;
  },
  
  daysInMonth: function(date) {
    return [31, (this.isLeapYear(date.getFullYear()) ? 29 : 28), 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][date.getMonth()];
  },
  
  isLeapYear: function (year) { 
      return ((year % 4 === 0 && year % 100 !== 0) || year % 400 === 0); 
  },
  
  padDay: function(number) {
    if (number <= 9) {
      return "0" + number;
    } 
    return number.toString();
  },
  
  padMonth: function(number) {
    return this.padDay(number);
  },
  
  min: function(date1, date2) {
    if (date1 <= date2) {
      return date1;
    }
    return date2;
  },
  
  toDate: function(date) {
    if (typeof(date) == 'string') {
      return this.fromString(date);
    }
    return date;
  },
  
  fromString: function(dateString) {
    string_without_time_information = dateString.split("T")[0];
    return new Date(string_without_time_information.gsub('-', '/'));
  },

  formatShort: function(date) {
    return date.getDate() + " " + this.shortMonthName(date.getMonth());
  },

  format: function(date) {
    return this.formatShort(date) + " " + date.getFullYear();
  },

  formatDateString: function(dateString) {
    var date = this.toDate(dateString);
    if (!this.isValidDate(date)) {
      return dateString;
    }
    return this.format(date);
  },

  isValidDate: function(date) {
    return !isNaN(date.getDay());
  },

  resetDay: function(date) {
    date.setHours(0);
    date.setMinutes(0);
    date.setSeconds(0);
    date.setMilliseconds(0);
    return date;
  }

};
Timeline.DateUtils.SHORT_MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
Timeline.DateUtils.FULL_MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

Timeline.DateUtils.MILLISECONDS_PER_DAY = 1000*60*60*24;

Timeline.DateRange = Class.create(Timeline.DateUtils, {
  
  initialize: function(start, end) {
    this.start = start;
    this.end = end;
  },
  
  contains: function(date) {
    date = this.toDate(date);
    return this.start <= date && date <= this.end;
  },
    
  formatAs: function(granularity) {
    if (granularity == 'days') {
      return this.format(this.start);
    }
    if (granularity == 'weeks') {
      return this.format(this.start) + ' - ' + this.format(this.end);
    }
    if (granularity == 'months') {
      return this.fullMonthName(this.start.getMonth()) + ' ' + this.start.getFullYear();
    }
  },
  
  daysBeforeEnd: function(date) {
    date = this.toDate(date);
    return this.differenceInDays(date, this.end);
  },
  
  daysAfterStart: function(date) {
    date = this.toDate(date);
    return this.differenceInDays(this.start, date);
  },

  durationInDays: function() {
    return this.differenceInDays(this.start, this.end);
  }
  
});

Timeline.PlanCalendar = Class.create(Timeline.DateUtils, {
  
  initialize: function(plan) {
    this.range = new Timeline.DateRange(this.fromString(plan.start_at), this.fromString(plan.end_at));
  },
  
  years: function() {
    var years = [];
    var day = this.range.start;
    do {
      years.push(new Timeline.DateRange(day, this.min(this.lastDayOfYear(day), this.range.end)));
      var newDay = new Date(day.getTime());
      newDay.setFullYear(day.getFullYear() + 1);
      newDay.setDate(1);
      newDay.setMonth(0);
      day = newDay;
    } while (this.range.contains(day));
    return years;
  },
  
  months: function() {
    var months = [];
    var day = this.range.start;
     do {
       var firstDayOfMonth = new Date(day.getTime());
       firstDayOfMonth.setDate(1);
       months.push(new Timeline.DateRange(firstDayOfMonth, this.lastDayOfMonth(day)));
       var newDay = new Date(day.getTime());
       newDay.setDate(1);
       newDay.setMonth(day.getMonth() + 1);
       day = newDay;
     } while(this.range.contains(day));
     return months;
  },
  
  weeks: function() {
    var weeks = [];
    var day = this.range.start;
    do {
      end_day = this.min(this.lastDayOfWeek(day), this.range.end);
      weeks.push(new Timeline.DateRange(day, end_day));
      day = this.addDays(end_day, 1);
    } while(this.range.contains(day));
    return weeks;
  },
  
  days: function() {
    var days = [];
    var day = this.range.start;
    
    while(this.range.contains(day)) {
      days.push(new Timeline.DateRange(day, day));
      day = this.addDays(day, 1);
    }
    
    return days;
  }
  
});