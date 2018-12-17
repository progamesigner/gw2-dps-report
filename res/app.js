(function () {
    Dropzone.autoDiscover = false;

    new Dropzone(
        document.getElementById('dropzone'),
        {
            acceptedFiles: '.zevtc,.evtc.zip,.evtc',
            clickable: true,
            init: function () {
                this.on('sending', function (file, xhr, form) {
                    var xhrsend = xhr.send;
                    xhr.send = function () {
                        xhrsend.call(xhr, file);
                    };
                    xhr.setRequestHeader('X-ACCESS-TOKEN', document.querySelector('[name="token"]').value);
                    xhr.setRequestHeader('X-EVTC-FILENAME', file.name);
                });
            },
            method: 'put',
            url: '/upload'
        }
    );
})(window);
