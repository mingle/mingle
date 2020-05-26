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
PlanWorkReport = {
  byProject: function(domId, projects, planWorksPath) {
    return {
      chart: {
        type: 'column',
        renderTo: domId
      },
      title:  { text:  'Work by project' },
      credits:  { enabled:  false },
      legend:  false,
      tooltip:  { 
        formatter:  function() { return 'Project <b>'+ this.x + '</b>: '+ this.y +' work items'; }
      },
      plotOptions:  {
        series:  {
          cursor:  'pointer',
          point:  {
            events:  {
              click:  function() {
                window.location = planWorksPath + '?' + 'filters=[project][is][' + escape(this.category.unescapeHTML()) + ']';
              }
            }
          }
        }
      },
      xAxis:  {
        categories:  projects.collect(function(project) { return project.name.gsub('&quot;', '\"'); })
      },
      yAxis:  {
        min:  0,
        allowDecimals:  false,
        title:  { text:  'Count of work items' }
      },
      series:  [{
        data:  projects.pluck('work_count')
      }]
    };
  }
};