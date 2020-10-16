$(document).ready(function () {
    EmailTemplates(2);
});
$("#CompanyId").change(function () {
    debugger;
    var CompanyId = $(this).val();
    var dt = new Date();
    var Year = dt.getFullYear();
    if (CompanyId !== "") {
        var ddlJobId = $('#JobId');
        var JobId = 0;
        SendAJAXRequest(`/Dashboard/CompanyJobs/?EmpId=${CompanyId}&year=${Year}&JobId=${JobId}`, 'GET', {}, 'JSON', (d) => {
            if (d) {
                ddlJobId.empty(); // Clear the plese wait  
                var valueofJobRoles = "";
                var v = "";
                $.each(d, function (i, v1) {
                    v += "<option value=" + v1.jobPostId + ">" + v1.jobTitleByEmployer + "</option>";
                });
                $("#JobId").html(v);
                $(".chosen-select").trigger("chosen:updated");
            } else {
                warnignPopup('Error!');
            }
        });

    }
});

function EmailTemplates(usrRole) {
    debugger;
    var ddlEmailTemplate = $("#ddlEmailTemplate");
    var TemplateId = 0;
    SendAJAXRequest(`/Dashboard/EmailTemplate/?UserRole=${usrRole}&Id=${TemplateId}`, 'GET', {}, 'JSON', (d) => {
        if (d) {
            ddlEmailTemplate.empty(); // Clear the plese wait  
            var v = "";
            $.each(d, function (i, v1) {
                v += "<option value=" + v1.id + ">" + v1.name + "</option>";
            });
            $("#ddlEmailTemplate").html(v);
            $(".chosen-select").trigger("chosen:updated");
        } else {
            warnignPopup('Error!');
        }
    });
}

function getTemplate(_this) {
    var usrRole = $('.nav-tabs .active a').text();
    if (usrRole == "Job Seeker") {
        usrRole = 2;
    }
    else {
        usrRole = 3;
    }
    var TemplateId = $('option:selected', _this).attr('value');
    SendAJAXRequest(`/Dashboard/EmailTemplate/?UserRole=${usrRole}&Id=${TemplateId}`, 'GET', {}, 'JSON', (d) => {
         if (d) {
            $("#ContentDiv").remove();
            $("#contentHolder").append(" " + d[0].emailBody + " ");
        } else {
            warnignPopup('Error!');
        }
    });
}
$("#JobId").change(function () {
    debugger;
    var JobId = $('option:selected', this).attr('value');
    var dt = new Date();
    var Year = dt.getFullYear();
    var CompanyId = $('#CompanyId option:selected').attr('value');
    SendAJAXRequest(`/Dashboard/CompanyJobs/?EmpId=${CompanyId}&year=${Year}&JobId=${JobId}`, 'GET', {}, 'JSON', (d) => {
        debugger;
        if (d) {
            $("#JobTitle").text("" + d[0].jobTitleByEmployer + "");
            $("#JobTitleIntable").text("" + d[0].jobTitleByEmployer + "");
            $("#skills").text("" + d[0].hiringCriteria + "");
            $("#LocationInTable").text("" + d[0].city + "," + d[0].state + "," + d[0].country+ "");
            $("#Location").text("" + d[0].city + " " + d[0].state + " " + d[0].country+ "");
            $("#CareerLavel").text("" + d[0].jobTypeSummary + "");
            $("#Salary").text("" + d[0].ctc + "");
            $("#JobPostedDate").text("" + d[0].postedOn + "");
            var Urlorigin = document.location.origin;
            Urlorigin = "" + Urlorigin + "/Job/JobDetails/?jobid=" + d[0].jobPostId + "";
            $("#JobPostId").attr("href", Urlorigin);
        } else {
            warnignPopup('Error!');
        }
    });
});

$("#JobSeekerNotification").submit(function (e) {
    debugger;
    e.preventDefault(); // avoid to execute the actual submit of the form.

    var form = $(this);
    var emailId = form.find('#JobSeekerId option:selected').attr('value');
    var subject = form.find('#JobId option:selected').text();
    var TempHtml = $("#ContentDiv").html();
    SendAJAXRequest(`/Dashboard/SendNotificationMail/?Email=${emailId}&htmlBody=${TempHtml}&Subject=${subject}`, 'GET', {}, 'JSON', (d) => {
        debugger;
        if (d) {
            alert("done");
        } else {
            warnignPopup('Error!');
        }
    });
  });