$(document).ready(function () {

    SendAJAXRequest(`/Dashboard/GetAdminDashboard`, "GET", {}, "html", function (resp) {
        if (resp && resp !== "") {
            $("div#contentHolder").html(resp);
        }
        else {
            return false;
        }
    });
});

function ManageUsers() {
    SendAJAXRequest(`/Dashboard/GetAllUsers`, "GET", {}, "html", function (resp) {
        if (resp && resp !== "") {
            $("div#contentHolder").html(resp);
        }
        else {
            return false;
        }
    });
}

function GetSuccessStoryVideo() {
    SendAJAXRequest(`/SuccessStoryVideo/GetSuccessStoryVideo`, "GET", {}, "html", function (resp) {
        if (resp && resp !== "") {
            $("div#contentHolder").html(resp);
        }
        else {
            return false;
        }
    });
}

function GetJobRoles() {
    SendAJAXRequest(`/JobTitle/GetJobTitle`, "GET", {}, "html", function (resp) {
        if (resp && resp !== "") {
            $("div#contentHolder").html(resp);
        }
        else {
            return false;
        }
    });
}

function GetStateList() {
    SendAJAXRequest(`/ManageCityState/StateList`, "GET", {}, "html", function (resp) {
        if (resp && resp !== "") {
            $("div#contentHolder").html(resp);
        }
        else {
            return false;
        }
    });
}

function GetCityList() {
    SendAJAXRequest(`/ManageCityState/GetAllCity`, "GET", {}, "html", function (resp) {
        if (resp && resp !== "") {
            $("div#contentHolder").html(resp);
        }
        else {
            return false;
        }
    });
}

function FeaturedJobs() {
    SendAJAXRequest(`/ManageJobs/FeaturedJobs`, "GET", {}, "html", function (resp) {
        if (resp && resp !== "") {
            $("div#contentHolder").html(resp);
        }
        else {
            return false;
        }
    });
}

function UsersReviews() {
    SendAJAXRequest(`/UsersReviews/UsersReviews`, "GET", {}, "html", function (resp) {
        if (resp && resp !== "") {
            $("div#contentHolder").html(resp);
        }
        else {
            return false;
        }
    });
}

function BulkJobs() {
    SendAJAXRequest(`/Dashboard/GetAllBulkJobs`, "GET", {}, "html", function (resp) {
        if (resp && resp !== "") {
            $("div#contentHolder").html(resp);
        }
        else {
            return false;
        }
    });
}

function manageadveritsement() {    
    SendAJAXRequest(`/DigitalDisplay/GetAllData`, "GET", {}, "html", function (resp) {
        if (resp && resp !== "") {
            $("div#contentHolder").html(resp);
        }
        else {
            return false;
        }
    });

}

function SendNotification() {
    SendAJAXRequest(`/Dashboard/SendNotification`, "GET", {}, "html", function (resp) {
        if (resp && resp !== "") {
            $("div#contentHolder").html(resp);
        }
        else {
            return false;
        }
    });
}

function EmailTemplate() {
    debugger;
    SendAJAXRequest(`/EmailTemplate/EmailTemplates`, "GET", {}, "html", function (resp) {
        if (resp && resp !== "") {
            $("div#contentHolder").html(resp);
        }
        else {
            return false;
        }
    });
}


