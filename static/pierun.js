
setDisplay = function() {
    var maxId = 0;
    return function(id) {
        return function(data) {
            console.log(id + ' ' + data.result)
            if(id > maxId) {
                maxId = id
                $('#display').html(data.result)
            }
        }
    }
}()

window.addEventListener("load", function(){
    var id = 0;
    $('#markdown').bind('input propertychange', function() {
        id = id + 1
        $.ajax({
            type: "POST",
            url: "/api/parse_markdown",
            data: JSON.stringify({ md: this.value }),
            contentType: 'application/json',
            success: setDisplay(id)
        })
    })
}, false);

