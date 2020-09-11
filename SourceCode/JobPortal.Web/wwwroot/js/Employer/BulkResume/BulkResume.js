function SelectJob(_this, e) {
    debugger;
    var allSelectedValues = "";
    var isFirst = true;

    $(".checkBoxClass:checked").each(function () {
        if ($(".checkBoxClass:checked").length > 10) {
            $(".checkBoxClass:last:checked").prop('checked', false);
            ErrorDialog('Warning', 'You can select max 10 job seeker to download');
            return false;
        } else {
            if (isFirst === true) {
                isFirst = false;

                allSelectedValues = $(this).val();
            } else {
                allSelectedValues = allSelectedValues + "," + $(this).val();
            }
        }
      });

    $('#JobSeekerTable').val(allSelectedValues);
};

function SelectAll() {
    debugger;
    var allSelectedValues = "";
    var isFirst = true;

    $(".checkBoxClass").each(function () {

        if (isFirst === true) {
            isFirst = false;

            allSelectedValues = $(this).val();
            $(".checkBoxClass").prop('checked', false);
        } else {
            allSelectedValues = allSelectedValues + "," + $(this).val();

            $(".checkBoxClass").prop('checked', true);
        }

    });
    $('#allselectcheckbox').removeAttr('onchange');
    $('#allselectcheckbox').attr('onchange', 'DSelectAll()');
    $('#JobSeekerTable').val(allSelectedValues);
}

function DSelectAll() {
    var allSelectedValues = "";
    var isFirst = true;

    $(".checkBoxClass").each(function () {

        if (isFirst === true) {
            isFirst = false;

            allSelectedValues = $(this).val();
            $(".checkBoxClass").prop('checked', false);
        } else {
            allSelectedValues = allSelectedValues + "," + $(this).val();

            $(".checkBoxClass").prop('checked', false);
        }

    });

    $('#allselectcheckbox').removeAttr('onchange');
    $('#allselectcheckbox').attr('onchange', 'SelectAll()');
    $('#JobSeekerTable').val('');
}

function DownloadResume() {
    debugger;
    let JobSeekerIds = $("#JobSeekerTable").val();
    if (JobSeekerIds === "") {
        ErrorDialog('Required', 'Please select records to proceed');
        return false;
    }
    var JobSeekerIdLength = JobSeekerIds.split(',');
    if (JobSeekerIdLength.length > 1) {
     SendAJAXRequest(`/Dashboard/BulkResumeDownload?UserIds=${JobSeekerIds}`, 'POST', {}, 'html', function (resp) {
       if (resp && resp !== "") {
           debugger;
           var zipLink = JSON.parse(resp).data;
           $("#ziplink").attr('href', zipLink);
           $('#ziplink').click(function () {
              this.click();
           }).click();

            InformationDialogWithPartialReload('Done', 'Resume has been downloaded', getJobSeekersBasedOnEmployerHiringCriteria());
        }
        else {
            ErrorDialog('Faild', 'Faild to download resume');
            return false;
        }
        });
    }
    else {
        SendAJAXRequest(`/Dashboard/SingleUserProfileDownload?UserIds=${JobSeekerIds}`, 'POST', {}, 'html', function (resp) {
            if (resp && resp !== "") {
                debugger;
                var zipLink = JSON.parse(resp).data;
                $("#ziplink").attr('href', zipLink);
                $('#ziplink').click(function () {
                    this.click();
                }).click();

                InformationDialogWithPartialReload('Done', 'Resume has been downloaded', getJobSeekersBasedOnEmployerHiringCriteria());
            }
            else {
                ErrorDialog('Faild', 'Faild to download resume');
                return false;
            }
        });
    }
}