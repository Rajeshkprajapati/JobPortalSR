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

    $('#dataTable_paginate').addClass('data-table-pasiganation');
    $('#dataTable_length').addClass('data-table-lenthFilter');
    $('#dataTable_filter').addClass('data-table-SearchFilter');

    SpecialChar('#StateCode');
    SpecialChar('#StateName');
});
function edit(_this) {
    //console.log(userid)
    $('#PopUpModal').on('show.bs.modal', function (event) {
        var button = $(event.relatedTarget);
        var titlename = button.data('name');// Extract info from data-* attributes
        $('div#StateRow').show();
        $('#StateCode').attr('readonly', true);
        $('#Country').css('pointerEvents', 'none');
        $('#Country').attr('readonly', true);
        var modal = $(this);
        modal.find('.modal-title').text('Edit Record of ' + titlename);
        var row = $(_this).closest('tr').find('td');

        //for (var i = 1; i < row.length-1; i++) {
        //    console.log(row[i].innerText);
        modal.find('#Country').val(row[0].innerText);
        modal.find('#StateCode').val(row[2].innerText);
        modal.find('#StateName').val(row[1].innerText);
        $("#SaveRec").hide();
        $("#updatebtn").removeClass('display-content');
        $("#Update").show();
        
    });

}
function Updatedata(_this) {
    let CountryCode = $('#Country').val().trim();
    var data = { CountryCode: CountryCode, StateCode: $('#StateCode').val().trim(), State: $('#StateName').val().trim() };
        SendAJAXRequest('/ManageCityState/UpdateState/', 'POST', data, 'JSON', (result) => {
            if (result) {
                $('#PopUpModal').modal('toggle');
                InformationDialogWithPartialReload('Done', 'You have successfully done this action.', GetStateList);
            } else {
                ErrorDialog('Error','Faild to do this action');
            }
        });
    }
   

function AddData(_this) {
    //alert($('#UserId').val());
    let CountryCode = $('#Country').val().trim();
    let StateCode = $('#StateCode').val().trim();
    let StateName = $('#StateName').val().trim();
    if (StateCode === "") {
        ErrorDialog('Required','Please fill state code');
        return false;
    }
    if (StateName === "") {
        ErrorDialog('Required','Please fill state name');
        return false;
    }
    if (CountryCode !== "0") {
        var data = { CountryCode: CountryCode, StateCode: $('#StateCode').val().trim(), State: $('#StateName').val().trim() };
        SendAJAXRequest('/ManageCityState/InsertState/', 'POST', data, 'JSON', (result) => {
            if (result) {
                //alert(result);
                //location.reload(true);
                if (result === 'State code already exist') {

                    ErrorDialog('Error', result);
                }
                else {
                    $('#PopUpModal').modal('toggle');
                    InformationDialogWithPartialReload('Done', 'You have successfully done this action.', GetStateList);
                }

                //location.reload(true);
            } else {
                ErrorDialog('Error', 'Faild to do this action');
            }
        });
    }
    else {
        ErrorDialog('Required','Please select country');
    }
}

//function deletedata(CountryCode, stateCode) {
function deletedata(data) {    
   // var data = { CountryCode: CountryCode, StateCode: stateCode };
    SendAJAXRequest('/ManageCityState/DeleteState/', 'POST', data, 'JSON', (result) => {
        if (result) {
            InformationDialogWithPartialReload('Done', result, GetStateList);
        } else {
            ErrorDialog('Error','Unable to do this action');
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
        $('#Country').css('pointerEvents','auto');
        
        $('#StateCode').attr('readonly', false);
       $("#StateCode").val('');
        $("#StateName").val('');
        $("#PopUpModalLabel").text("Add state");
    });

}
$("#StateName","#StateCode").keypress(function (e) {
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
    var data = { CountryCode: countryId, StateCode:stateId };
    ConfirmationDialog('Confirmation', 'Are you sure', deletedata, data);
}