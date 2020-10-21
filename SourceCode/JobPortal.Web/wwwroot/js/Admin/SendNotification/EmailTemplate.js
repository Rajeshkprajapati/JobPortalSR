$(document).ready(function () {

    $('#dataTable').dataTable({
        // 'columnDefs': [{ "searchable": false, 'orderable': false, 'targets': 5 }]
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

    //SpecialChar('#StateCode');
    //SpecialChar('#StateName');
});
function edit(_this) {
    debugger;
    //console.log(userid)
    $('#PopUpModal').on('show.bs.modal', function (event) {
        var row = $(_this).closest('tr').find('td');
        $('#error_sp_msg').hide();
        $('#TemplateId').val(row[0].innerText);
        $('#TemplateName').val(row[1].innerText);
        $('#TemplateSubject').val(row[2].innerText);
        $('#UserRole').val(row[4].innerText);
        $('#TemplateHtml').val(row[3].innerText);
        $("#SaveRec").hide();
        $("#updatebtn").removeClass('display-content');
        $("#Update").show();

    });

}
function Updatedata(_this) {
    debugger;
    let TemplateId = $('#TemplateId').val().trim();
    let TemplateName = $('#TemplateName').val().trim();
    let TemplateSubject = $('#TemplateSubject').val().trim();
    let UserRole = $('#UserRole').val().trim();
    let TemplateHtml = $('#TemplateHtml').val().trim();
    let data = { Id: TemplateId, EmailBody: TemplateHtml, Subject: TemplateSubject, UserRole: UserRole, Name: TemplateName  };
    SendAJAXRequest(`/EmailTemplate/UpdateEmailTemplate`, "POST", data, "JSON", function (resp) {
        if (resp) {
            InformationDialog('Done', 'Successfully Updated');
        }
        else {
            ErrorDialog('Fail', 'could not update');
        }
    });
}


function AddData(_this) {
    debugger;
    //alert($('#UserId').val());
    let CountryCode = $('#Country').val().trim();
    let StateCode = $('#StateCode').val().trim();
    let StateName = $('#StateName').val().trim();
    if (StateCode === "") {
        ErrorDialog('Required', 'Please fill state code');
        return false;
    }
    if (StateName === "") {
        ErrorDialog('Required', 'Please fill state name');
        return false;
    }
    if (CountryCode !== "0") {
        var data = { CountryCode: CountryCode, StateCode: $('#StateCode').val().trim(), State: $('#StateName').val().trim() };
        //SendAJAXRequest('/ManageCityState/InsertState/', 'POST', data, 'JSON', (result) => {
        //    if (result) {
        //        //alert(result);
        //        //location.reload(true);
        //        if (result === 'State code already exist') {

        //            ErrorDialog('Error', result);
        //        }
        //        else {
        //            $('#PopUpModal').modal('toggle');
        //            InformationDialogWithPartialReload('Done', 'You have successfully done this action.', GetStateList);
        //        }

        //        //location.reload(true);
        //    } else {
        //        ErrorDialog('Error', 'Faild to do this action');
        //    }
        //});
    }
    else {
        ErrorDialog('Required', 'Please select country');
    }
}

//function deletedata(CountryCode, stateCode) {
function deletedata(data) {
    // var data = { CountryCode: CountryCode, StateCode: stateCode };
    SendAJAXRequest('/ManageCityState/DeleteState/', 'POST', data, 'JSON', (result) => {
        if (result) {
            InformationDialogWithPartialReload('Done', result, GetStateList);
        } else {
            ErrorDialog('Error', 'Unable to do this action');
        }
    });
}




function AddNew() {
    //console.log(userid)
    $('#PopUpModal').on('show.bs.modal', function () {
        $("#Update").hide();
        $("#SaveRec").show();
        $("#updatebtn").addClass('display-content');
        //$('div#StateRow').hide();
        $('#Country').attr('readonly', false);
        $('#Country').css('pointerEvents', 'auto');

        $('#StateCode').attr('readonly', false);
        $("#StateCode").val('');
        $("#StateName").val('');
        $("#PopUpModalLabel").text("Add state");
    });

}
$("#StateName", "#StateCode").keypress(function (e) {
    $("#error_sp_msg").remove();
    var k = e.keyCode,
        $return = (k > 64 && k < 91 || k > 96 && k < 123 || k === 8 || k === 32 || k >= 48 && k <= 57);
    if (!$return) {
        $("<span/>", {
            "id": "error_sp_msg",
            "html": "Special characters not allowed !!!!!"
        }).insertAfter($(this));
        return false;
    }

});

$('#PopUpModal').on('hidden.bs.modal', function () {
    $("#error_sp_msg").remove();

});

function ConfrimationDeleteState(countryId, stateId) {
    //$('#confimationDeleteModel').modal({
    //    dismissible: true
    //});
    //$('#btndelete').attr('onclick', 'deletedata("' + countryId + '","' + stateId + '")');
    //$('#confimationDeleteModel').modal('show');
    //$("#confimationDeleteModel").addClass("open");
    //$("#confimationDeleteModel").addClass("in");
    var data = { CountryCode: countryId, StateCode: stateId };
    ConfirmationDialog('Confirmation', 'Are you sure', deletedata, data);
}