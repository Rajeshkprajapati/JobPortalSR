//"use strict";
$(function () {

    var connection = new signalR.HubConnectionBuilder().withUrl("/ActiveUsers").build();

    connection.start().then(function () {
        connection.invoke("ActiveUserCount").catch(function (err) {
            //return console.error(err.toString());
        });
    }).catch(function (err) {
        return console.error(err.toString());
    });

    connection.on("UserCount", function (message) {
        $('#activeUserCount').text(message);
    });

});
