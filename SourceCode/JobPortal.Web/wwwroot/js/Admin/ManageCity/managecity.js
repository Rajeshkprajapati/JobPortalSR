﻿
let mastercity = {};

mastercity = (function () {
    let addnew = function () {
        debugger;
        $('#cityModal').find('form').get(0).reset();
        $('button[name=update][id=Update]').hide();
        $('button[name=add][id=Add]').show();

        $('label#PopUpModalLabel').text('Add Record');
        $('input[type=text][name=CityCode]').prop('readonly', false);
    }
    let editrow = function (_this) {
        $('label#PopUpModalLabel').text('Edit Record');
        $('div#cityModal').find('form').get(0).reset();
        $('button[name=add][id=Add]').hide();
        $('button[name=update][id=Update]').show();

        $('input[type=text][name=CityCode]').prop('readonly', true);

        var row = $(_this).closest('tr').find('td');
        $('select[name=StateCode][id=StateCode]').val(row[0].innerText);
        $('input[type=text][name=City]').val(row[1].innerText);
        $('input[type=text][name=CityCode]').val(row[2].innerText);
    }

    let deletecity = function (citycode, statecode) {
        SendAJAXRequest(`/ManageCityState/DeleteCity/?citycode=${citycode}&statecode=${statecode}`, 'GET', {}, 'JSON', (resp) => {
            if (resp && resp.msg) {
               InformationDialogWithPartialReload('Done', 'You have successfully done this action.', GetCityList);
            } else {
               let message = "Unable to delete city";
               ErrorDialog('Warning', message);
            }
        });
    }

    let adddata = function (data) {
        SendAJAXRequest(`/ManageCityState/AddCity`, 'POST', data, 'JSON', (resp) => {
            if (resp && resp.msg) {
                $('#PopUpModal').modal('toggle');
                InformationDialogWithPartialReload('Done', 'You have successfully done this action.', GetCityList);
            } else {
               let message = "Seems City Code is already exist! Please verify";
               ErrorDialog('Warning', message);
            }
        });
    }

    let updatedata = function (data) {
        SendAJAXRequest(`/ManageCityState/UpdateCity`, 'POST', data, 'JSON', (resp) => {
            if (resp && resp.msg) {
                $('#PopUpModal').modal('toggle');
                InformationDialogWithPartialReload('Done', 'You have successfully done this action.', GetCityList);
            } else {
                let message = "City Code is already exist! Please verify";
                ErrorDialog('Warning', message);
            }
        });
    }

    return {
        addnew: addnew,
        editrow: editrow,
        deletecity: deletecity,
        adddata: adddata,
        updatedata: updatedata,
    }

})();

function addnew() {
    mastercity.addnew();
}

function edit(_this) {
    mastercity.editrow(_this);
}

function addcity(_this) {
    let form = $(_this).parent().parent().find("form");
    let formData = ResolveFormData(form);
    if (formData[0].StateCode == "--Select State--" || formData[0].City == "" || formData[0].CityCode == "") {
        let message = "Please enter a valid data";
        ErrorDialog('Warning', message);
        return false;
    }
    mastercity.adddata(formData[0]);
}
function updatecity(_this) {
    let form = $(_this).parent().parent().find("form");
    let formData = ResolveFormData(form);
    if (formData[0].StateCode == "--Select State--" || formData[0].City == ""  || formData[0].CityCode == "" ) {
        let message = "Please enter a valid data";
        ErrorDialog('Warning', message);
        return false;
    }
    mastercity.updatedata(formData[0]);
}

function deletedata(citydata) {    
    mastercity.deletecity(citydata.citycode, citydata.statecode);
}

function DeleteCityConfirmation(citycode, statecode) {
    var data = { citycode, statecode };
    ConfirmationDialog('Confirmation', 'Are you sure', deletedata, data);

}


//function ConfrimationCityDeleteMessage(cityid, stateid) {
//    let options = {
//        backdrop: 'static',
//        show: true
//    };
//    $('#btndelete').attr('onclick', 'deletedata("' + cityid + '","' + stateid + '")');
//    $("#confimationDeleteModel").addClass("open");
//    $("#confimationDeleteModel").addClass("in");
//    $('#confimationDeleteModel').modal(options);
//}

$(function () {
    $('#dataTable').dataTable({
        //'columnDefs': [{ "searchable": false, 'orderable': false, 'targets': 5 }],

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

    SpecialChar('#CityCode');
    SpecialChar('#CityName');
    SpecialChar('#StateCode');
});