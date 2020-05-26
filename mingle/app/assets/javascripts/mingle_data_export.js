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
(function ($) {
  var timer = null;
  function showExportProgressMessage() {
    $('#in-progress-message').show();
  }

  function hideExportProgressMessage() {
    $('#in-progress-message').hide();
  }

  function hideExportButton() {
    $('#mingle-data-export').hide();
  }

  function hideExportStatus() {
    $('.export-status').hide();
  }

  function showExportStatus() {
    $('.export-status').show();
  }

  function displayExportButton() {
    $('#mingle-data-export').show();
  }

  function displayCancelButton() {
    $('#cancel-data-export').show();
  }

  function hideCancelButton() {
    $('#cancel-data-export').hide();
  }

  function displayProgressMessage(exportData) {
    $('.export-status .message').empty();
    $('.export-status .export-trigger-info').text('The last export was started at {startDate}'.supplant({startDate: formattedDateTime(exportData.created_at)}));
  }

  function enableProgressTransition() {
    console.log("enabling");
    $('.export-status .export-progress-bar .ui-progressbar-value').addClass('transition');
  }

  function disableProgressTransition() {
    console.log("disabling");
    $('.export-status .export-progress-bar .ui-progressbar-value').removeClass('transition');
  }

  function displayErrorMessage(exportData) {
    $('.export-status .message').empty();
    $('.export-status .message').addClass('error-box');
    $('.export-status').addClass('error');
    var msg1 = $j('<span></span>', {text: 'Something went wrong. Please try again or '});
    var email = $j('<a></a>', {text: 'Report this error.', href: supportEmailLink(exportData)});
    $('.export-status .message').append(msg1).append(email);
  }

  function completionPercentage(completed, total) {
    var percentage = 0;
    if (!(completed === 0 || completed === undefined)) {
      percentage = Math.floor((completed / total)* 100);
    }
    return "{percentage}%".supplant({percentage: percentage});
  }

  function supportEmailLink(exportData) {
    var subject = 'Mingle export error';
    var body = "Tenant: {url}\n".supplant({url: window.location.href}) +
               "User: {user}\n".supplant({user: AlsoViewing.CurrentUser()}) +
               "Export id: {exportId}\n" .supplant({exportId: exportData.id})+
               "Completion: {completed}/{total}\n".supplant({completed: exportData.completed, total: exportData.total}) +
               "Started at: {dateTime}\n".supplant({dateTime: formattedDateTime(exportData.created_at)});
    return "mailto:support@thoughtworks.com?body={body}&subject={subject}".supplant({body: encodeURI(body), subject: encodeURI(subject)});
  }

  function displayExportProgress(exportData) {
    hideExportButton();
    displayProgressMessage(exportData);
    if (exportData.status === 'error') {
      displayErrorMessage(exportData);
    }
    $('#export-container .export-status .export-progress-bar').progressbar({
      max: exportData.total,
      value: exportData.completed,
      change: function (e, _) {
        var completed = $j(e.target).progressbar('option', 'value');
        var total = $j(e.target).progressbar('option', 'max');
        $(e.target).find('.ui-progressbar-value .progress-msg').text(completionPercentage(completed, total));
      },
      create: function (e, _) {
        var msgElement = $j('<span></span>', {class: 'progress-msg', text: completionPercentage(exportData.completed, exportData.total)});
        $(e.target).find('.ui-progressbar-value').append(msgElement);
      }
    });
  }

  function disableCheckbox() {
    $('input[type="checkbox"]').attr('disabled', true);
  }

  function enableCheckbox() {
    $('input[type="checkbox"]').attr('disabled', false);
  }

  function setupExportButtonHandler() {
    $('#mingle-data-export').on('click', function () {
      $.ajax({
        type: 'POST',
        url: '/exports',
        data: $j('#export-checklist-form').serializeArray().reduce(function(results,x){ results[x.name]= x.value; return results;},{}),
        success: function (data) {
          showExportStatus();
          displayCancelButton();
          showExportProgressMessage();
          collapseExportOptions();
          disableCheckbox();
          removeDownloadLink();
          $('.export-status').removeClass('error');
          displayExportProgress(data);
          enableProgressTransition();
          $('.export-status .message').removeClass('error-box');
          pollExportStatus(data.id);
        }
      });
    });
  }

  function setupCancelButtonHandler() {
    $('#cancel-data-export').on('click', function () {
      if(timer) {
        clearTimeout(timer);
      }
      $.ajax({
        type: 'DELETE',
        url: '/exports/delete',
        success: function (data) {
          expandExportOptions();
          enableCheckbox();
          hideCancelButton();
          hideExportProgressMessage();
          displayExportButton();

          if (data && data.status === 'completed') {
            insertDownloadLink(data);
            displayExportProgress(data);
            displayExportButton();
            showExportStatus();
            disableProgressTransition();
          } else if (data && data.status === 'error') {
            displayErrorMessage(data);
            displayExportProgress(data);
            displayExportButton();
            showExportStatus();
            disableProgressTransition();
          } else {
            hideExportStatus();
          }
        }
      });
    });
  }

  function updateProgressValue(exportData) {
    $('#export-container .export-status .export-progress-bar').progressbar("option", "value", exportData.completed);
  }


  function pollExportStatus(exportId) {
    $.ajax({
      type: 'GET',
      url: '/exports.json',
      data: {id: exportId},
      success: function (data) {
        showExportStatus();
        updateProgressValue(data);
        if (data.status === 'in progress') {
          showExportProgressMessage();
          displayCancelButton();
        }
        if (data.status === 'completed') {
          hideExportProgressMessage();
          hideCancelButton();
          displayExportButton();
          insertDownloadLink(data);
          disableProgressTransition();
          enableCheckbox();
          expandExportOptions();
        } else if (data.status === 'error') {
          expandExportOptions();
          hideExportProgressMessage();
          hideCancelButton();
          enableCheckbox();
          displayExportButton();
          displayErrorMessage(data);
          disableProgressTransition();
        } else {
          timer = setTimeout(function () {
            pollExportStatus(exportId);
          }, 5000);
        }
      },
      error: function () {
        location.reload();
      }
    });
  }

  function formattedDateTime(dateTime) {
    return new Date(dateTime).format('dd mmm yyyy hh:nn a/p');
  }

  function insertDownloadLink(exportData) {
    var downloadButton = $j('<button></button>', {
      text: "Download",
      class:'data-export-download-link'
    });
    downloadButton.on('click', function(){ window.location.href = '/exports/{exportId}/download'.supplant({exportId: exportData.id});});
    $('#export-container .export-status').append(downloadButton);
  }

  function removeDownloadLink(){
    $('.data-export-download-link').remove();
  }

  function projectDataCheckboxHandler() {
    var e =this;

    var allProjectDataCheckboxes = $("#export-checklist-form .project-data-checkbox");
    var allProjectHistoryCheckboxes = $("#export-checklist-form .project-history-checkbox");
    var allProjectsCheckbox = $("#export-checklist-form #all-projects-data-checkbox");
    var allProjectsHistoryCheckbox = $("#export-checklist-form #all-projects-history-checkbox");

    var history_element_id = e.id + '_for_history';
    $("#"+ history_element_id ).each(function() {
      $(this).prop('disabled',!e.checked);
      $(this).prop('checked',  e.checked);
    });

    var selectedProjectDataCheckboxes = allProjectDataCheckboxes.filter(':checked');
    var selectedProjectHistoryCheckboxes = allProjectHistoryCheckboxes.filter(':checked');

    if (allProjectHistoryCheckboxes.length > 0 && allProjectHistoryCheckboxes.length === selectedProjectHistoryCheckboxes.length) {
      allProjectsHistoryCheckbox.prop("checked", true);
    } else {
      allProjectsHistoryCheckbox.prop("checked", false);
    }

    if (allProjectDataCheckboxes.length > 0 && allProjectDataCheckboxes.length === selectedProjectDataCheckboxes.length) {
      allProjectsCheckbox.prop("checked", true);
      allProjectsHistoryCheckbox.prop("disabled", false);
    } else {
      allProjectsCheckbox.prop("checked", false);
      allProjectsHistoryCheckbox.prop("disabled", true);
    }
  }

  function collapseExportOptions() {
    $j("#export-checklist-form").accordion("option", {active: false, animate: 1000});
  }

  function expandExportOptions() {
    $j("#export-checklist-form").accordion("option", {active: 0, animate: 1000});
  }

  function initAccordion(activate) {
    $j("#export-checklist-form").accordion({
      collapsible: true,
      active: activate ? 0 : false,
      icons: {
        header: "fa fa-angle-right",
        activeHeader: "fa fa-angle-down"
      }
    });
  }

  $(document).ready(function () {
    var allProjectDataCheckboxes = $("#export-checklist-form .project-data-checkbox");
    var allProjectHistoryCheckboxes = $("#export-checklist-form .project-history-checkbox");
    var allProjectsCheckbox = $("#export-checklist-form #all-projects-data-checkbox");
    var allProjectsHistoryCheckbox = $("#export-checklist-form #all-projects-history-checkbox");
    var allProgramDataCheckboxes = $("#export-checklist-form .program-data-checkbox");
    var allProgramsCheckbox = $("#export-checklist-form #all-programs-data-checkbox");


    for (i = 0, len = allProjectDataCheckboxes.length; i < len; i++){
      allProjectDataCheckboxes[i].on('click', projectDataCheckboxHandler);
    }

    if ($('#export-container').length < 1) return;
    var exportData = JSON.parse($('#export-container').attr('data-export'));
    if ((exportData && exportData.status === 'completed')) {
      displayExportProgress(exportData);
      disableProgressTransition();
      insertDownloadLink(exportData);
      displayExportButton();
      initAccordion(true);
    } else if (exportData && exportData.hasOwnProperty('status')) {
      displayExportProgress(exportData);
      enableProgressTransition();
      pollExportStatus(exportData.id);
      initAccordion(false);
      disableCheckbox();
    } else {
      initAccordion(true);
      hideExportStatus();
    }
    setupExportButtonHandler();
    setupCancelButtonHandler();

    allProjectsCheckbox.on('change', function () {
      var e = $( this );
      $("#export-checklist-form .project-checkbox").each(function () {
        $(this).prop('checked', e.prop('checked')) ;
      });
      allProjectHistoryCheckboxes.each(function () {
        $(this).prop('disabled', !e.prop('checked'));
      });
      allProjectsHistoryCheckbox.each(function () {
        $(this).prop('disabled', !e.prop('checked'));
      });
    });

    allProjectsHistoryCheckbox.on('change', function () {
      var e = $( this );
      allProjectHistoryCheckboxes.each(function () {
        $(this).prop('checked', e.prop('checked'));
      });
    });

    allProgramsCheckbox.on('change', function () {
      var e = $( this );
      allProgramDataCheckboxes.each(function () {
        $(this).prop('checked', e.prop('checked'));
      });
    });


    $("#export-checklist-form").on("change", function(e) {
      var all = $("#export-checklist-form input[type='checkbox']");
      var selected = all.filter(":checked");
      var button =  $("#export-checklist-form input[type='button']");

      var selectedProgramDataCheckboxes = allProgramDataCheckboxes.filter(':checked');
      var selectedProjectHistoryCheckboxes = allProjectHistoryCheckboxes.filter(':checked');
      var selectedProjectDataCheckboxes = allProjectDataCheckboxes.filter(':checked');

      if (selected.length > 0) {
        button.prop('disabled', false);
      } else {
        button.prop('disabled', true);
      }

      if (allProjectHistoryCheckboxes.length > 0 && allProjectHistoryCheckboxes.length === selectedProjectHistoryCheckboxes.length) {
        allProjectsHistoryCheckbox.prop("checked", true);
      } else {
        allProjectsHistoryCheckbox.prop("checked", false);
      }

      if (allProjectDataCheckboxes.length > 0 && allProjectDataCheckboxes.length === selectedProjectDataCheckboxes.length) {
        allProjectsCheckbox.prop("checked", true);
        allProjectsHistoryCheckbox.prop("disabled", allProjectsCheckbox.prop('disabled'));
      } else {
        allProjectsCheckbox.prop("checked", false);
        allProjectsHistoryCheckbox.prop("disabled", true);
      }

      if (allProgramDataCheckboxes.length > 0 && allProgramDataCheckboxes.length === selectedProgramDataCheckboxes.length) {
        allProgramsCheckbox.prop("checked", true);
      } else {
        allProgramsCheckbox.prop("checked", false);
      }

    }).trigger('change');
  });

})(jQuery);
