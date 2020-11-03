$(document).ready(function () {
    $("select[name=minExp]").change(function () {
        let minExp = parseInt(this.value);
        $("select[name=maxExp] option").each(function (i, o) {
            if (parseInt(o.value) < minExp) {
                $(o).prop("disabled", true);
            }
            else {
                $(o).removeAttr("disabled");
            }
        });
    });
    $("select[name=MinExperiance]").change(function () {
        let minExp = parseInt(this.value);
        $("select[name=MaxExperiance] option").each(function (i, o) {
            if (parseInt(o.value) < minExp) {
                $(o).prop("disabled", true);
            }
            else {
                $(o).removeAttr("disabled");
            }
        });
    });
   
    //Job Title Bind By job industry are id  
    $("#JobIndustryAreaId").change(function () {
         var JobIndustryAreaId = $(this).val();
        if (JobIndustryAreaId !== "") {
            SendAJAXRequest(`/Home/JobTitlesById/?JobIndustryAreaId=${JobIndustryAreaId}`, 'GET', {}, 'JSON', (d) => {
                if (d) {
                        $('#hdnJobTitleId').val('');
                        $('.multiselect-selected-text').text('Choose Job Title');
                        $("ul.multiselect-container li").not('li:first').remove();
                        var JobTitleli = "";
                        var optionsdBind = "";
                        $.each(d, function (i, v1) {
                            JobTitleli += "<li> <a tabindex=" + '0' + "><label class=" + 'checkbox' + " title='" + v1.jobTitleName + "'><input type=" + 'checkbox' + " value=" + v1.jobTitleId + "> " + v1.jobTitleName + "</label></a></li>";
                            optionsdBind += "<option value=" + v1.jobTitleId + ">" + v1.jobTitleName + "</option>";
                        });
                        $("ul.multiselect-container").append(JobTitleli);
                        $("#JobTitle").html(optionsdBind);
                   
                } else {
                    warnignPopup('Error!');
                }
            });

        }
    });
    

    multiselector.initSelector(
        $('select#JobTitle'),
        {
            nonSelectedText: 'Select job role'
        },
        $("input[type=hidden]#hdnJobTitleId"),
        ","
    );
    $("ul.multiselect-container li").not('li:first').remove();


    $('.slidepartners').slick({
        slidesToShow: 1,
        slidesToScroll: 6,
        autoplay: true,
        autoplaySpeed: 2500,
        arrows: false,
        dots: false,
        //cssEase: 'linear',
        pauseOnHover: true,
        responsive: [{
            breakpoint: 768,
            settings: {
                slidesToShow: 1
            }
        }, {
            breakpoint: 520,
            settings: {
                slidesToShow: 1
            }
        }]
    });
});

function EmployerFollower(id) {
    if (id === 0) {
        ErrorDialog("Login Required","Please login or register to follow company");
        return false;
    }
    else {
        var data = "";
        SendAJAXRequest("/Home/EmployerFollower/?EmployerId=" + id + "", 'POST', data, 'JSON', function (result) {
            if (result) {
                InformationDialog('Information', 'Successfully done');
                location.reload(true);
            } else {
                ErrorDialog('Error','Please try again');
            }
        });
    }
}

var slideIndex = 0;
var intraval = 2000;
showSlides();
function showSlides() {
        var i;
        var slides = document.getElementsByClassName("mySlides");
        var dots = document.getElementsByClassName("mySlides");
        for(i = 0; i < slides.length; i++) {
            slides[i].style.display = "none";
         }
        slideIndex++;
        if (slideIndex > slides.length) { slideIndex = 1 }
        for (i = 0; i < dots.length; i++) {
            dots[i].className = dots[i].className.replace(" active", "");
        }
        slides[slideIndex - 1].style.display = "";
        dots[slideIndex - 1].className += " active";
       
        setTimeout(showSlides, intraval);
}
$('#myslideUl').hover(function () {
    intraval = 10000;
});

$('#myslideUl').mouseout(function () {
   intraval = 2000;
});
$(document).on('change', "ul.multiselect-container li input[type=checkbox]", function () {
    if ($('.multiselect-container li.active').length > 2) {

        var nonSelectedOptions = $('ul.multiselect-container li').filter(function () {
            return !$(this).is('.active');
        });
        nonSelectedOptions.each(function () {
            let jTitlevalue = $(this).find('a').find('label').find('input[type=checkbox]').val();
            console.log(jTitlevalue);
            let input = $(' input[type = checkbox][value="' + jTitlevalue + '"]');
            input.prop('disabled', true);
            input.parent('li').addClass('disabled');
        });
     }
    else {
        var allOptions = $('ul.multiselect-container li');
        allOptions.each(function () {
            let jTitlevalue = $(this).find('a').find('label').find('input[type=checkbox]').val();
            console.log(jTitlevalue);
            let input = $(' input[type = checkbox][value="' + jTitlevalue + '"]');
            input.prop('disabled', false);
            input.parent('li').removeClass('disabled');
        });
    }
});