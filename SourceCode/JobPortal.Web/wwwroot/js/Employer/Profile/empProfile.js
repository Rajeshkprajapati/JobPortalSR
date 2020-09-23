function changePassword() {

    $('#PasswordForm').submit(function (e) {
        e.preventDefault();
    });
    
    //var formData = ResolveFormData(_this);

    let oldPassword = $('input[name=OldPassword]').val();
    let Password = $('input[name=Password]').val();
    let ConfirmPassword = $('input[name=ConfirmPassword]').val();
  
    if ((ConfirmPassword == null || ConfirmPassword == '') || (Password == null || Password == '')) {
        ErrorDialog('Warning', 'Empty password fields are not allowed');
        return false;
    }
    if (ConfirmPassword != Password) {
        //if (ConfirmPassword.toUpperCase() != Password.toUpperCase()) {
        ErrorDialog('Warning', 'Password and Confirm Password must be same');
        return false;
    }

    if (Password.length < 6) {
        //if (ConfirmPassword.toUpperCase() != Password.toUpperCase()) {
        ErrorDialog('Warning', 'Password must be atleast 6 character long');
        return false;
    }
    if (validatePassword(Password) === false) {
        //if (ConfirmPassword.toUpperCase() != Password.toUpperCase()) {
        ErrorDialog('Warning', 'Password must contain at least one letter, one number and one special character');
        return false;
    }

    //var formData = new FormData();
    //formData.append('OldPassword', oldPassword);
    //formData.append('Password', Password);

    var formData = {
        oldPassword, Password
    }

    SendAJAXRequest("/Auth/ChangePassword/", 'post', formData, 'json', function (result) {
        if (result === true) {

            InformationDialog('Information', 'Password successfully changed');
        } else {
            ErrorDialog('Error', 'Current password is not correct');
        }
    });
    resetForm($('#PasswordForm'));
    return false;
}

function UpdateEmpDetail() {
    $("#empProfile").submit(function (e) {
        e.preventDefault();
    });
    let Cname = $('input[name=CompanyName]').val();
    if (Cname.length < 2) {
        ErrorDialog('Error', 'Company Name should be atleast 2 character long');
        return false;
    }
    let ContactPerson = $('input[name=Fullname]').val();
    if (ContactPerson.length < 2) {
        ErrorDialog('Error', 'Name should be atleast 2 character long');
        return false;
    }

    let email = $('input[name=Email]').val();
    if (Cname.length < 2) {
        ErrorDialog('Error', 'Company Name should be atleast 2 character long');
        return false;
    }
    let phone = $('input[name=MobileNo]').val();
    if (phone.length < 10) {
        ErrorDialog('Error', 'Mobile Number should be atleast 10 digit long');
        return false;
    }
    let address = $('input[name=Address]').val();
    if (address.length < 10) {
        ErrorDialog('Error', 'Address should be atleast 10 character long');
        return false;
    }

    var formData = new FormData();
    if ($("#profilepic").val()) {
        var fileUpload = $("#profilepic").get(0);
        var files = fileUpload.files;
        formData.append("ImageFile", files[0]);
    }

    formData.append('CompanyName', Cname);
    formData.append('FirstName', ContactPerson);
    formData.append('Email', email);
    formData.append('MobileNo', phone);
    formData.append('Address1', address);


    SendAJAXRequest("/EmployerManagement/UpdateProfile/", "POST", formData, "JSON", function (result) {
        if (result === true) {
            InformationDialog('Information', 'Profile details added/updated successfully');
            //location.reload(true);
        } else {
            ErrorDialog('Error', 'Failed to update profile details!');
        }
    }, null, true);

    return false;
}
//For Alphabet only
$("#ContactPerson").each(function () {
    $(this).keypress(function (e) {
        $("#error_sp_msg").remove();
        var k = e.keyCode,
            $return = ((k > 64 && k < 91) || (k > 96 && k < 123) || k === 8 || k === 32);
        if (!$return) {
            $("<span/>", {
                "id": "error_sp_msg",
                "html": "Special characters/numbers are not allowed !!!!!",
                "style": "color:red"
            }).insertAfter($(this));
            return false;
        }
    });
});
//for numbers only
$("#phoneNumber").each(function () {
    $(this).keypress(function (e) {
        $("#error_sp_msg").remove();
        var k = e.keyCode,
            $return = (k >= 48 && k <= 57);
        if (!$return) {
            $("<span/>", {
                "id": "error_sp_msg",
                "html": "Special characters/alphabets are not allowed !!!!!",
                "style": "color:red"
            }).insertAfter($(this));
            return false;
        }
    });
});

