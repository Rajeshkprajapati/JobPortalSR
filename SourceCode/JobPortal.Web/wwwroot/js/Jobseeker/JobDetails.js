function ApplyJobs(id) {
    //var data = { jobPostId: id };
    var currentUrl = window.location.href;

    //$('#confimationModel').modal('hide');
    //$('#loader').show();
    SendAJAXRequest('/Job/ApplyJob/?jobPostid=' + id + '&currentUrl=' + currentUrl, 'get', {}, 'json', (result) => {
        //$('#loader').hide();
        if (result && result.returnUrl) {
            window.location.href = result.returnUrl;
        }
        else if (result === 'Job applied' || result === 'Congratulations! Job applied successfully.') {
            InformationDialogWithPageRelode('congratulation', result);
        }
        else if (result === 'You have already applied this job') {
            ErrorDialog('Warning', result);
        }

        else if (result === 'Oops! Applicable For Job Seeker Only.') {
            ErrorDialog('Warning', result);
        }
        else if (result === 'To apply job please complete your profile') {
            ErrorDialog('Warning', result);
        }
        else if (result === 'Please login to apply this job') {
            window.location.href = '/Auth/';
        }
        else {
            ErrorDialog('Warning', result);
        }
    });
}
function showModal() {
    $('#myModal').modal('show');
}
function RedirectProfile() {
    window.location.href = '/JobSeekerManagement/Profile/';
}
function ConfrimationFoJobApply(id) {

    $('#confimationModel').modal({
        dismissible: true
    });
    $('#applyJobsbutton').attr('onclick', 'ApplyJobs(' + id + ')');
    $('#confimationModel').modal('show');
    $("#confimationModel").removeClass("open");
    $("#confimationModel").addClass("in");
}
function redirectLogin() {
    window.location.href = '/Auth/';
}
function ReloadPage() {
    location.reload();
}
function WarningPopup() {
    ErrorDialog("Login Required", "Please login or register to apply job");
    return false;
}
$(document).ready(function () {
    pageSize = 6;
    incremSlide = 6;
    startPage = 0;
    numberPage = 0;
});