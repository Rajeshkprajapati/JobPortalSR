let adminLayout = {};

adminLayout = (function () {
    let initialize = function () {
        getNotificationsCounter();
    };

    let getNotificationsCounter = function () {
        SendAJAXRequest('/Notifications/GetNotificationsCounter/', 'GET', {}, 'JSON', (data) => {
            if (data && data.counts) {
                if (data.counts.totalNotifications> 0) {
                    $("i#aggregate-notification-bell").text(data.counts.totalNotifications);
                    $("i#aggregate-notification-bell").show();
                }
                else {
                    $("i#aggregate-notification-bell").hide();
                }

                if (data.counts.newAddedUsersCount > 0) {
                    $("span#manage-users-badge").text(data.counts.newAddedUsersCount);
                    $("span#manage-users-badge").show();
                    //$("span#manage-users-badge").click(function (evt) {
                    //    evt.preventDefault();
                    //    evt.stopPropagation();
                    //    window.location.href = "/Dashboard/GetAllUsers/?uv=true";
                    //});
                }
                else {
                    $("span#manage-users-badge").hide();
                }
            }
        });
    };

    return {
        initialize: initialize
    };

})();

$(document).ready(function () {
    adminLayout.initialize();
    SendAJAXRequest('/Home/SuccessStory/', 'GET', {}, 'JSON', (data) => {
        if (data) {
            var videSection = $('#videSection');
            $(videSection).empty();
            for (var i = 0; i < data.length; i++) {
                $(videSection).append('<div class="col-md-5 video-border"> <iframe height = "100%" width = "100%" src="' + data[i].video + '" frameborder = "0" allowfullscreen = "allowfullscreen" ></iframe> </div>');
            }
        } else {
            warnignPopup('Error');
        }

    });

    $(window).scroll(function () {
        var scroll = $(window).scrollTop();
        if (scroll >= 60) {
            //console.log('a');
            $(".popupdata").addClass("scrollPopup");
        } else {
            //console.log('a');
            $(".popupdata").removeClass("scrollPopup");
        }
    });
});

