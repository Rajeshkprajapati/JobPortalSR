﻿
let dashboard = {};

dashboard = (function () {
    let globalFilter = {};
    let messageSection = {};
    let jobSeekersSection = {};
    messageSection.calendar = messageSection.calendar || null;
    
    let init = function () {
        
        $("div.dashboard-nav-inner").find('ul').find("li").click(function () {
            let items = $(this).closest("ul").find("li");
            items.each(function (i, e) {
                $(e).removeClass("active");
            });
            $(this).addClass("active");
        });

        

        //$("ul.usernavdash").find("li").eq(0).click();

        //appending dashboard data
        SendAJAXRequest(`/Dashboard/EmpDashboardData`, 'GET', {}, "html", function (resp) {
            if (resp && resp !== "") {
                $("div#mycontentHolder").html(resp);
            }
            else {
                return false;
            }
        });
    };
    

    let employerDetails = function () {
        SendAJAXRequest(`/Dashboard/GetEmployerDetail`, "GET", {}, "html", function (resp) {
            if (resp && resp !== "") {
                $("div#mycontentHolder").html(resp);
            }
            else {
                return false;
            }
        });
    };

    let initCalendar = function (selector, date) {
        let isCalendarOpen = false;
        messageSection.calendar = tail.DateTime(selector, {
            dateFormat: "YYYY-mm-dd",
            timeFormat: false,
            position: "bottom",
            closeButton: false,
            dateStart: new Date('01/01/2015')
        })
            .on("open", () => {
                isCalendarOpen = true;
            })
            .on("close", () => {
                isCalendarOpen = false;
            })
            .on("change", () => {
                if (isCalendarOpen) {
                    isCalendarOpen = !isCalendarOpen;
                    getMessages();
                }
            });
        messageSection.calendar.selectDate(date);
    };

    let getJobs = function () {        
        let year = $("select[name=jobListYearFilter]").val();
        year = (year && year !== "") ? year : new Date().getFullYear();
        SendAJAXRequest(`/Dashboard/GetJobs?year=${year}`, "GET", {}, "html", function (resp) {
            if (resp && resp !== "") {
                $("div#mycontentHolder").html(resp);
                if ($("select[name=jobListYearFilter]").val() !== year) {
                    $("select[name=jobListYearFilter]").val(year);                    
                }
            }
            else {
                return false;
            }
        });
    };

    let getMessages = function () {        
        let date = messageSection.calendar ? messageSection.calendar.fetchDate() : null;
        let _date = date ? date : new Date();
        SendAJAXRequest(`/Dashboard/GetMessages?date=${_date.toDateString()}`, "GET", {}, "html", function (resp) {
            if (resp && resp !== "") {
                $("div#mycontentHolder").html(resp);
                initCalendar("input[type=text]#dateToFilterMessages", _date);
            }
            else {
                return false;
            }
        });
    };

    let getJobSeekers = function () {
        SendAJAXRequest(`/Dashboard/GetJobSeekers`, "GET", {}, "html", function (resp) {
            if (resp && resp !== "") {
                $("div#mycontentHolder").html(resp);
            }
            else {
                return false;
            }
        });
    };

    let getViewedProfiles = function () {
        SendAJAXRequest(`/Dashboard/GetViewedProfiles`, "GET", {}, "html", function (resp) {
            if (resp && resp !== "") {
                $("div#mycontentHolder").html(resp);
            }
            else {
                return false;
            }
        });
    };

    let getJobSeekersBasedOnEmployerHiringCriteria = function () {        
        let year = $("#dropFilterYear").val() || new Date().getFullYear();
        let city = $("select[name=ddlCity]").val() || "";
        let jobRole = $("select[name=ddlJobRoles]").val() || "";        
        SendAJAXRequest(`/Dashboard/GetJobSeekersBasedOnEmployerHiringCriteria?year=${year}&city=${city}&role=${jobRole}`, "GET", {}, "html", function (resp) {
            if (resp && resp !== "") {
                $("div#mycontentHolder").html(resp);
                $("select[name=ddlJobRoles]").val(jobRole);
                $("select[name=ddlCity]").val(city);                
                $("#dropFilterYear").val(year);                
            }
            else {
                return false;
            }
        });
    };

    let populateJobOnForm = function (jobId) {
        
        SendAJAXRequest(`/Dashboard/GetJobScreenById?jobId=${jobId}`, "GET", {}, "html", function (resp) {
            if (resp && resp !== "") {
                $("div#editJob").find("div.modal-body").html(resp);
                $("div#editJob").modal({
                    backdrop: "static"
                });                                            
                $("#jobRole").prop('disabled', true).trigger("chosen:updated");                
            }
            else {
                return false;
            }
        });
    };
    let populateDraftJobOnForm = function (jobId) {        
        SendAJAXRequest(`/Dashboard/GetDraftJobScreenById?jobId=${jobId}`, "GET", {}, "html", function (resp) {
            if (resp && resp !== "") {
                $("div#editJob").find("div.modal-body").html(resp);
                $("div#editJob").modal({
                    backdrop: "static"
                });                                            
                $("#jobRole").trigger("chosen:updated");                
            }
            else {
                return false;
            }
        });
    };

    let getReplyPrompt = function (msg) {
        SendAJAXRequest(`/Dashboard/GetReplyPrompt`, "POST", msg, "html", function (resp) {
            if (resp && resp !== "") {
                $("div#emailPromptContainer").find("div.modal-body").html(resp);
                $("div#emailPromptContainer").modal({
                    backdrop: "static"
                });
            }
            else {
                return false;
            }
        });
    };

    let updateJob = function (data) {        
        let bodyContent = $("#cke_jobDetails iframe").contents().find("body").html();
        data.jobDetails = bodyContent;
        SendAJAXRequest(`/Dashboard/UpdateJobDetails`, "POST", data, "JSON", function (resp) {
            if (resp && resp.isUpdated) {
                closeModalManually($("div#editJob"));
                $("ul.usernavdash").find("li").eq(2).click();
                InformationDialog('Information', 'Successfully updated job details');               
            }
            else {
                return false;
            }
        });
    };

    let PostDraftJob = function (data) {        
        let bodyContent = $("#cke_jobDetails iframe").contents().find("body").html();
        data.jobDetails = bodyContent;
        SendAJAXRequest(`/Dashboard/UpdateJobDetails`, "POST", data, "JSON", function (resp) {
            if (resp && resp.isUpdated) {
                closeModalManually($("div#editJob"));
                $("ul.usernavdash").find("li").eq(2).click();
                InformationDialogWithPageRelode('Information', 'Successfully posted draft job!');                
                //debugger;
                //PostDraftJob(data);
            }
            else {
                return false;
            }
        });
    };

    let replyToJobSeeker = function (data) {       
        SendAJAXRequest(`/Dashboard/ReplyToJobSeeker`, "POST", data, "JSON", function (resp) {
            if (resp && resp.isSuccess) {
                closeModalManually($("div#emailPromptContainer"));
                let Message = "Successfully replied";                
                getMessages();
                InformationDialog('Information', Message);                
            }
            else {
                return false;
            }
        });
    };
    let addjobs = function () {
        SendAJAXRequest(`/Dashboard/AddJobsPartial`, "GET", {}, "html", function (resp) {
            if (resp && resp !== "") {
                $("div#mycontentHolder").html(resp);
            }
            else {
                return false;
            }
        });
    };

    let draftjobs = function () {        
        let year = $("select[name=jobListYearFilter]").val();
        year = (year && year !== "") ? year : new Date().getFullYear();
        SendAJAXRequest(`/Dashboard/GetDraftJobs?year=${year}`, "GET", {}, "html", function (resp) {
            if (resp && resp !== "") {
                $("div#mycontentHolder").html(resp);
                if ($("select[name=jobListYearFilter]").val() !== year) {
                    $("select[name=jobListYearFilter]").val(year);
                }
            }
            else {
                return false;
            }
        });
    };

    let myProfile = function () {
        
        SendAJAXRequest(`/Dashboard/MyProfilePartial`, "GET", {}, "html", function (resp) {
            if (resp && resp !== "") {
                $("div#mycontentHolder").html(resp);
                tabSetting();
                $(this).addClass("active");
            }
            else {
                return false;
            }
        });
    };


    const tabSetting = function () {
        $("div.dashboard-nav-inner").find('ul').find('li').click(function () {
            let items = $(this).closest("ul").find("li");
            items.each(function (i, e) {
                $(e).removeClass("active");
            });
            $(this).addClass("active");
        });
    }
    return {
        init: init,
        employerDetails: employerDetails,
        getJobs: getJobs,
        getJobSeekers: getJobSeekers,
        getViewedProfiles: getViewedProfiles,
        getJobSeekersBasedOnEmployerHiringCriteria: getJobSeekersBasedOnEmployerHiringCriteria,
        populateJobOnForm: populateJobOnForm,
        populateDraftJobOnForm: populateDraftJobOnForm,
        updateJob: updateJob,
        PostDraftJob: PostDraftJob,
        getMessages: getMessages,
        messageSection: messageSection,
        getReplyPrompt: getReplyPrompt,
        replyToJobSeeker: replyToJobSeeker,
        addjobs: addjobs,
        myProfile: myProfile,
        draftjobs: draftjobs
    };

})();

function myProfile() {
    dashboard.myProfile();
}

function addjobs() {
    dashboard.addjobs();
}

function getMyDetails() {
    dashboard.employerDetails();
}

function getMyJobs() {
    dashboard.getJobs();
}
function draftjobs() {
    dashboard.draftjobs();
}

function getJobSeekers() {
    dashboard.getJobSeekers();
}

function logOut() {
    sharable.logOutUser();
}

function getViewedProfiles() {
    dashboard.getViewedProfiles();
}

function getMessages() {
    dashboard.getMessages();
}

function getJobSeekersBasedOnEmployerHiringCriteria() {
    dashboard.getJobSeekersBasedOnEmployerHiringCriteria();
}

function populateJobOnForm(jobId) {
    dashboard.populateJobOnForm(jobId);
}
function populateDraftJobOnForm(jobId) {
    dashboard.populateDraftJobOnForm(jobId);
}

function getReplyPrompt(msg) {
    dashboard.getReplyPrompt(msg);
}

function replyToJobSeeker(_this) {
    let forms = $(_this).parent().parent().find("form");
    let formsData = ResolveFormData(forms);
    formsData.forEach(function (f, i) {
        let bodyContent = $("#cke_txtBody iframe").contents().find("html").html();
        f.Body = bodyContent;
        dashboard.replyToJobSeeker(f);
    });
}

function yearChanged() {
    dashboard.getJobs();
}

function updateJob(_this) {
   
    let forms = $(_this).parent().parent().find("form");
    let formsData = ResolveFormData(forms);
    dashboard.updateJob(formsData[0]);
}
function PostDraftJob(_this) {
    debugger;
    let forms = $(_this).parent().parent().find("form");
    let formsData = ResolveFormData(forms);
    formsData[0].JobTitle = $('.jobRoles').val().toString();
    dashboard.PostDraftJob(formsData[0]);
}

function toggleCalendar() {
    dashboard.messageSection.calendar.toggle();
}

$(function () {
    dashboard.init();
});