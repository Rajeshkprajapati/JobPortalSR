$(document).ready(function () {
$('#dataTable').dataTable({
        // 'columnDefs': [{ "searchable": false, 'orderable': false, 'targets': 5 }]
        "ordering": false,
        aoColumnDefs: [
            {
                bSortable: false,
                aTargets: [-1]
            },
            {
                bSearchable: false,
                aTargets: [-1]
            }
        ]
    });
    $('#dataTable_length').addClass('data-table-lenthFilter');
    $('#dataTable_filter').addClass('data-table-SearchFilter');
});

function jobStatusDetails(jobStatus) {
    debugger;
    let year = new Date().getFullYear();
    SendAJAXRequest(`/Dashboard/GetJobStatus?year=${year}&JobStatus=${jobStatus}`, "GET", {}, "html", function (resp) {
        if (resp && resp !== "") {
            $("div#contentTableHolder").html(resp);
        }
        else {
            return false;
        }
    });
}


function DeactiveActiveJob(jobpostid) {
    debugger;
    SendAJAXRequest(`/Dashboard/DactiveActiveJob?JobPostId=${jobpostid}`, 'GET', {}, 'JSON', (result) => {
        if (result) {
            InformationDialogWithPartialReload('Done', 'Job closed successfully', jobStatusDetails(1));
        } else {
            ErrorDialog('Error', result);

        }
    });
}

$("#activeJobs").click(function () {
    $(this).addClass('active');
    $("#closedJobs").removeClass('active');
});

$("#closedJobs").click(function () {
    $(this).addClass('active');
    $("#activeJobs").removeClass('active');
});

function CloseJobConfirmation(data) {
    ConfirmationDialog('Confirmation', 'Are you sure to close this job?', DeactiveActiveJob, data);
}