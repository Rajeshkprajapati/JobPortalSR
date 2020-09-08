$(document).ready(function () {

    $('#dataTable').dataTable({
        // 'columnDefs': [{ "searchable": false, 'orderable': false, 'targets': 5 }]
        "ordering":false,
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
function edit(_this) {
    $('#PopUpModal').on('show.bs.modal', function (event) {
        var button = $(event.relatedTarget);
        var titlename = button.data('name');// Extract info from data-* attributes

        var modal = $(this);
        modal.find('.modal-title').text(titlename + ' Record');
        var row = $(_this).closest('tr').find('td');
        if (titlename === 'Edit') {
            modal.find('#JobPostId').val(row[0].innerText);
            modal.find('#jobTitle').val(row[1].innerText);
            modal.find('#companyname').val(row[2].innerText);
            modal.find('#displayOrder').val(row[3].innerText);

            $('#error_sp_msg').hide();
            $("#SaveRec").hide();
            $("#Update").show();
        }
        
    });

}
function Updatedata() {
    let JobPostId = $('#JobPostId').val();
    let FeaturedJobDisplayOrder = $('#displayOrder').val();

    SendAJAXRequest(`/ManageJobs/UpdateFeaturedJobDisplayOrder/?JobPostId=${JobPostId}&FeaturedJobDisplayOrder=${FeaturedJobDisplayOrder}`, 'GET', {}, 'json', (result) => {
        if (result) {
            $('#PopUpModal').modal('toggle');
            InformationDialogWithPartialReload('Done', result.msg, FeaturedJobs);
        }
    });
}
function deletedata(jobpostid) {
    SendAJAXRequest(`/ManageJobs/DeleteFeaturedJob/?jobpostid=${jobpostid}`, 'GET', {}, 'JSON', (result) => {
        if (result) {
            InformationDialogWithPartialReload('Done', result.msg, FeaturedJobs);
        } else {
            ErrorDialog('Error',"Unable to delete");

        }
    });
}

$("#Designation,#Abbrivation").each(function () {
    $(this).keypress(function (e) {
        $("#error_sp_msg").remove();
        var k = e.keyCode,
            $return = ((k > 64 && k < 91) || (k > 96 && k < 123) || k === 8 || k === 32);
        if (!$return) {
            $("<span/>", {
                "id": "error_sp_msg",
                "html": "Special characters/numbers not allowed !!!!!",
                "style": "color:red"
            }).insertAfter($(this));
            return false;
        }
    });
});


