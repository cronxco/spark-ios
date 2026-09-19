var SparkPageCapture = function () {};

SparkPageCapture.prototype = {
    run: function (arguments) {
        var clone = document.documentElement.cloneNode(true);
        var removable = clone.querySelectorAll(
            "script, style, noscript, template, iframe, object, embed, canvas, svg",
        );

        Array.prototype.forEach.call(removable, function (element) {
            element.remove();
        });

        var canonical = document.querySelector('link[rel="canonical"]');
        var canonicalURL = canonical ? canonical.href : "";
        var url = /^https?:/i.test(canonicalURL)
            ? canonicalURL
            : window.location.href;
        var html = "<!doctype html>" + clone.outerHTML;
        var maximumBytes = 5 * 1024 * 1024;

        if (new Blob([html]).size > maximumBytes) {
            arguments.completionFunction({
                url: url,
                title: document.title.slice(0, 1000),
                captureError: "too_large",
            });
            return;
        }

        arguments.completionFunction({
            url: url,
            title: document.title.slice(0, 1000),
            html: html,
        });
    },
};

var ExtensionPreprocessingJS = new SparkPageCapture();
