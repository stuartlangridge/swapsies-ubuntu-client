import QtQuick 2.2
import Ubuntu.Components 1.1

/*!
    \brief MainView with a Label and Button elements.
*/

MainView {
    id: root
    // objectName for functional testing purposes (autopilot-qt5)
    objectName: "mainView"

    // Note! applicationName needs to match the "name" field of the click manifest
    applicationName: "swapsies.sil"

    /*
     This property enables the application to change orientation
     when the device is rotated. The default is false.
    */
    //automaticOrientation: true


    width: units.gu(100)
    height: units.gu(75)

    function exec_Code(code) {
        console.log("got code!", code);
    }
    function exec_Seconds(seconds) {
        console.log("got seconds!", seconds);
    }
    function exec_Pair(identifier) {
        console.log("got pair!", identifier);
    }

    property var seenLines: [];
    function processServerGetCodeResponse(lines) {
        for (var i=0; i<lines.length; i++) {
            if (lines[i].trim() === "") {
                // blank line
                continue;
            } else if (root.seenLines[i] === lines[i]) {
                // seen this line before
                continue;
            } else if (lines[i].indexOf(":") === -1) {
                // invalid line
                console.log("Received invalid server line '" + lines[i] + "'");
                continue;
            } else {
                var parts = lines[i].trim().split(":");
                if (parts.length !== 2) {
                    console.log("Received invalid server command '" + lines[i] + "'");
                    continue;
                }
                var fn = root["exec_" + parts[0]];
                if (!fn) {
                    console.log("Received unknown server command '" + parts[0] + "'");
                    continue;
                }
                fn(parts[1]);
            }
        }
        root.seenLines = lines;
    }
    function resetReadyForNextRequest() {
        root.seenLines = [];
    }

    function removePendingCodeRequest(code, status) {
        return function() {
            for (var i=0; i<pendingCodeRequests.count; i++) {
                var le = pendingCodeRequests.get(i);
                if (le.code === code && le.status === status) {
                    pendingCodeRequests.remove(i);
                    break;
                }
            }
        }
    }

    function sendCode(code) {
        pendingCodeRequests.append({code: code, status: "pending"});
        var listElem = pendingCodeRequests.get(pendingCodeRequests.count - 1);
        var xhr = new XMLHttpRequest();
        xhr.open("POST", "http://localhost:3000/sendcode?code=" + code + "&id=uniq");
        xhr.onreadystatechange = function() {
            if (xhr.readyState == 4) {
                var j;
                try {
                    j = JSON.parse(xhr.responseText);
                } catch(e) {
                    console.log("Got invalid JSON from sendcode", xhr.responseText);
                    listElem.status = "error";
                    return;
                }
                if (j.status == "ok") {
                    console.log("got new identifier", j.identifier);
                    listElem.status = "done";
                    root.fireAfter(2000, root.removePendingCodeRequest(code, "done"));
                } else {
                    console.log("Got problem from server on sendcode", j.status);
                    listElem.status = "problem";
                    root.fireAfter(2000, root.removePendingCodeRequest(code, "problem"));
                }
            }
        }
        xhr.send("");
    }

    function fireAfter(interval, callback) {
        var name = "fireAfter" + Math.random();
        var timer = Qt.createQmlObject("import QtQuick 2.2; " +
                                       "Timer {interval: " + interval + "; repeat: false; running: true;}",
                                       root, name);
        timer.triggered.connect(callback);

        return {cancel: function() {
            timer.stop();
            delete timer;
        }};
    }

    function getCode() {
        var xhr = new XMLHttpRequest();
        xhr.open("POST", "http://localhost:3000/getcode?id=uniq", true);
        var timer = root.fireAfter(5000, function() {
            xhr.abort();
            console.log("server request timed out error");
        });
        xhr.onreadystatechange = function() {
            if (xhr.readyState == 4) {
                root.resetReadyForNextRequest();
            } else if (xhr.readyState == 3) {
                // partial response
                timer.cancel();
                root.processServerGetCodeResponse(xhr.responseText.split("\n"));
            }
        }
        xhr.send("");
    }

    Tabs {
        Tab {
            title: i18n.tr("Swapsies")
            page: Page {

                Column {
                    id: "col"
                    spacing: units.gu(1)
                    anchors {
                        margins: units.gu(2)
                        fill: parent
                    }

                    Label {
                        id: labelgive
                        objectName: "labelgive"

                        text: i18n.tr("When you meet someone else and want to swap, you can...")
                    }

                    Button {
                        id: buttongive
                        objectName: "buttongive"
                        width: parent.width

                        text: i18n.tr("Get a code to give them")

                        onClicked: {
                            root.getCode();
                        }
                    }
                    Label {
                        id: labelenter
                        objectName: "labelenter"

                        text: i18n.tr("or enter <i>their</i> code, below")
                    }

                    ListModel {
                        id: pendingCodeRequests
                    }

                    Repeater {
                        model: pendingCodeRequests
                        Rectangle {
                            height: pendLabel.height * 1.2
                            width: pendLabel.width
                            color: {
                                switch (model.status) {
                                case "pending": return "#aaaa00"; break;
                                case "done": return "#00aa00"; break;
                                case "error": return "#aa0000"; break;
                                case "problem": return "#666600"; break;
                                default: return "white"
                                }
                            }
                            Behavior on color { ColorAnimation { duration: 350; } }

                            Label {
                                anchors.centerIn: parent
                                id: pendLabel
                                fontSize: "small"
                                text: "Fetching code " + model.code
                                color: "white"
                                width: col.width
                            }

                        }
                    }

                    TextField {
                        id: tfenter
                        placeholderText: "0000"
                        inputMethodHints: Qt.ImhDigitsOnly
                        maximumLength: 4
                        selectByMouse: false
                        validator: IntValidator { bottom: 1000; top: 9999; }
                        inputMask: "D999"
                        onLengthChanged: {
                            if (tfenter.text.length === 4) {
                                root.sendCode(tfenter.text);
                                tfenter.text = "";
                            }
                        }
                    }

                }
            }
        }

        Tab {
            title: i18n.tr("Winnings")
            page: Page {
                Column {
                    id: "col2"
                    spacing: units.gu(1)
                    anchors {
                        margins: units.gu(2)
                        fill: parent
                    }

                    Label {
                        text: "win"
                    }

                }
            }
        }
    }
}
