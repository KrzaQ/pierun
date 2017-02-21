
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
    $('#code').bind('input propertychange', function() {
        // $.post("api/parse_markdown", { md: this.value }).done(function(data){
        //     console.log(data)
        // })
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

