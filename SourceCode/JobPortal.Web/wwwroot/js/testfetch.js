//const uri = '/SearchResume/TodoItems';
//let todos = [];

//function getItems() {
//    fetch(uri)
//        .then(response => response.json())
//        .then(data => _displayItems(data))
//        .catch(error => console.error('Unable to get items.', error));
//}
//function _displayItems(data) {
//    alert(data);
//}




//function status(response) {
//    if (response.status >= 200 && response.status < 300) {
//        return Promise.resolve(response)
//    } else {
//        return Promise.reject(new Error(response.statusText))
//    }
//}

//function json(response) {
//    return response.json()
//}
//function SendfetchRequest(url, method,datatoSend,cb) {
//    $("div.windows8").show();
//    fetch(url, {
//        method: method,
//        headers: {
//            //"Content-type": "application/x-www-form-urlencoded; charset=UTF-8"
//            "Content-type": "application/json; charset=UTF-8"
//        },
//        body: datatoSend
//    })
//        //.then(status)
//        .then(json)
//        .then(data => cb(data))
//        .catch(function (error) {
//            console.log('Request failed', error);
//        });
//}


//function getItems() {
//    debugger
//    let formdata = new FormData();
//    formdata.append('Test', 'This is form data');
//    SendfetchRequest('/SearchResume/TodoItems', 'POST', formdata, (resp) => {
//        alert(resp);
//    });
//}
