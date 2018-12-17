(function () {
    new Dropzone(
        document.getElementById('dropzone'),
        {
            clickable: true,
            init: function () {
                this.on('addedfile', function (file) {
                });
                this.on('complete', function (file) {
                });
                this.on('sending', function (file, xhr, form) {
                    var xhrsend = xhr.send;
                    xhr.send = function () {
                        xhrsend.call(xhr, file);
                    };
                    xhr.setRequestHeader('X-ACCESS-TOKEN', document.querySelector('[name="token"]').value);
                    xhr.setRequestHeader('X-EVTC-FILENAME', file.name);
                });
                this.on('previewTemplate', function (file) {
                });
                this.on('success', function (file) {
                });
                this.on('thumbnail', function (file, dataUrl) {
                });
                this.on('uploadprogress', function (file, progress, bytesSent) {
                });
            },
            method: 'put',
            url: '/upload'
        }
    );
})(window);
