$(document).ready(function () {

});
$("#CompanyId").change(function () {
    debugger;
    var CompanyId = $(this).val();
    var dt = new Date();
    var Year = dt.getFullYear();
    if (CompanyId !== "") {
        var ddlJobId = $('#JobId');
        SendAJAXRequest(`/Dashboard/CompanyJobs/?EmpId=${CompanyId}&year=${Year}`, 'GET', {}, 'JSON', (d) => {
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