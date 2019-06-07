(function () {
    Dropzone.autoDiscover = false;

    var token = document.querySelector('[name="token"]') || document.createElement('input');
    var webhook = document.querySelector('[name="webhook"]');

    try {
        var storage = window.localStorage;

        var handler = function (key) {
            return function (event) {
                var value = event.currentTarget.value;
                if (value) {
                    storage.setItem(key, value);
                } else {
                    storage.removeItem(key);
                }
            }
        };

        token.value = document.querySelector('[name="token"]') ? storage.getItem('token') : '';
        webhook.value = storage.getItem('discord_webhook');
        token.addEventListener('change', handler('token'));
        webhook.addEventListener('change', handler('discord_webhook'));
    } catch (error) {
        console.error(error);
    }

    new Dropzone(
        document.getElementById('dropzone'),
        {
            acceptedFiles: '.zevtc,.evtc.zip,.evtc',
            clickable: true,
            init: function () {
                this.on('sending', function (file, xhr) {
                    var xhrsend = xhr.send;
                    xhr.send = function () {
                        xhrsend.call(xhr, file);
                    };
                    xhr.setRequestHeader('X-ACCESS-TOKEN', token.value);
                    xhr.setRequestHeader('X-EVTC-FILENAME', file.name);
                });
                this.on('success', function (file, response) {
                    var url = new URL(response.name, window.location.origin);
                    var xhr = new XMLHttpRequest();

                    webhook.disabled = true;
                    webhook.parentNode.classList.add('is-loading');

                    xhr.open('POST', webhook.value);
                    xhr.setRequestHeader('Content-Type', 'application/json');
                    xhr.onreadystatechange = function () {
                        webhook.disabled = false;
                        webhook.parentNode.classList.remove('is-loading');
                    };
                    xhr.send(JSON.stringify({
                        embeds: [{
                            color: response.isSuccess ? 3897943 : 11216719,
                            description: [
                                'PoV: ' + response.recorderName + ' (' + response.recorderProfession + ')',
                                'Duration: ' + response.fightDuration,
                                'Success: ' + response.isSuccess ? 'Success :thumbsup:' : 'Failed :thumbsdown:'
                            ].join('\n'),
                            footer: {
                                text: file.name
                            },
                            provider: {
                                name: "Progamesigner's GW2 DPS Report",
                                url: "https://github.com/progamesigner/gw2-dps-report"
                            },
                            timestamp: response.fightEnd,
                            title: 'DPS Report (' + response.fightName + ')',
                            url: url.href
                        }]
                    }));
                });
            },
            method: 'put',
            url: '/upload'
        }
    );

    document.querySelectorAll('a[rel="external"]').forEach(function (element) {
        element.addEventListener('click', function (event) {
            event.preventDefault();

            window.open(element.getAttribute('href'));
        });
    });
})(window);
