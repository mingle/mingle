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
function remainingTimeForMingleEol(endDate, today) {
  function getMonth(date) {
    return date.getMonth() + 1;
  }

  function calcRemainingMonths(endDate, today) {
    var remainingMonths = 0;
    if (endDate.getFullYear() !== today.getFullYear())
      remainingMonths = getMonth(endDate) + (12 - getMonth(today));
    else
      remainingMonths = getMonth(endDate) - getMonth(today);
    return remainingMonths;
  }
  var result = '', remainingDays;
  var remainingMonths = calcRemainingMonths(endDate, today);
  remainingDays = today.getMonthDays() - today.getDate();
  if (remainingMonths > 0)
    result = remainingMonths + (remainingMonths > 1 ? ' months' : ' month');
  if (remainingDays > 0)
    result += (remainingMonths > 0 ? " and " : '') + remainingDays + (remainingDays > 1 ? ' days' : ' day');
  return result;
}

