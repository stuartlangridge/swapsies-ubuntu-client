import QtQuick 2.2
import Ubuntu.Components 1.1
import U1db 1.0 as U1db
import QtQuick.Layouts 1.1


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


    width: units.gu(40)
    height: units.gu(71)

    U1db.Database { id: db; path: "swapsies.u1db" }
    U1db.Document {
        id: myid
        database: db
        docId: "myid"
        create: true
        Component.onCompleted: {
            if (!myid.contents || !myid.contents.myid) {
                myid.contents = {myid: Qt.md5(Math.random() + "-" + Math.random())};
            }
        }
    }
    U1db.Index {
        database: db
        id: by_identifier
        /* You have to specify in the index all fields you want to retrieve
           The query should return the whole document, not just indexed fields
           https://bugs.launchpad.net/u1db-qt/+bug/1271973 */
        expression: ["things.identifier"]
    }
    U1db.Query {
        id: identifiers
        index: by_identifier
        query: ["*"]
    }

    function exec_Code(code) {
        console.log("got code!", code);
        mycode.text = code;
        col.state = "gotcode";
    }
    function exec_Seconds(seconds) {
        console.log("got seconds!", seconds);
        labelcountdown.text = seconds;
    }
    function exec_Pair(identifier) {
        console.log("got pair!", identifier);
        db.putDoc({things: {identifier: identifier}})
        var newface = Qt.createQmlObject("import QtQuick 2.2; " +
                "Face {height: parent.height; width: parent.height; identifier: '" + identifier + "'}",
                                       addedPairs);
        root.fireAfter(6000, function() {
            newface.destroy();
        });
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
        col.state = "";
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
        xhr.open("POST", "http://swapsies.popey.com/sendcode?code=" + code + "&id=" + myid.contents.myid);
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
                    db.putDoc({things: {identifier: j.identifier}})
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
        mycode.text = "....";
        col.state = "gotcode";
        var xhr = new XMLHttpRequest();
        xhr.open("POST", "http://swapsies.popey.com/getcode?id=" + myid.contents.myid, true);
        var timer = root.fireAfter(5000, function() {
            xhr.abort();
            console.log("server request timed out error");
            col.state = "";
            buttongive.state = "error";
            root.fireAfter(2000, function() {
                buttongive.state = "";
                root.resetReadyForNextRequest();
            });
        });
        xhr.onreadystatechange = function() {
            console.log("rst", xhr.readyState);
            if (xhr.status == 0) {
                console.log("Some sort of connection error. :(", xhr.responseText, "!", xhr.readyState);
                timer.cancel();
                col.state = "";
                buttongive.state = "error";
                root.fireAfter(2000, function() {
                    buttongive.state = "";
                    root.resetReadyForNextRequest();
                });
                return;
            }

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
                    Face {
                        anchors.horizontalCenter: parent.horizontalCenter
                        identifier: myid.contents.myid
                        width: parent.width / 2
                        height: parent.width / 2
                    }

                    states: [
                        State {
                            name: ""
                            PropertyChanges { target: labelgive; visible: true }
                            PropertyChanges { target: buttongive; visible: true }
                            PropertyChanges { target: labelgotmycode; visible: false }
                            PropertyChanges { target: mycode; visible: false }
                            PropertyChanges { target: labelcountdown; visible: false }
                        },
                        State {
                            name: "gotcode"
                            PropertyChanges { target: labelgive; visible: false }
                            PropertyChanges { target: buttongive; visible: false }
                            PropertyChanges { target: labelgotmycode; visible: true }
                            PropertyChanges { target: mycode; visible: true }
                            PropertyChanges { target: labelcountdown; visible: true }
                        }
                    ]

                    Label {
                        id: labelgotmycode
                        text: i18n.tr("Show others this code to swap with you:")
                        visible: false
                        wrapMode: Text.Wrap
                        width: parent.width
                    }

                    Label {
                        id: mycode
                        text: "0000"
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                        fontSize: "x-large"
                        visible: false

                        Row {
                            id: addedPairs
                            width: parent.width
                            height: parent.height / 2
                            spacing: units.gu(0.5)

                            add: Transition {
                                id: newPair

                                SequentialAnimation {
                                    ParallelAnimation {
                                        NumberAnimation {
                                            property: "scale";
                                            from: 0;
                                            to: 15;
                                            duration: 50
                                        }
                                        NumberAnimation {
                                            property: "x";
                                            from: mycode.width / 2;
                                            to: mycode.width / 2;
                                            easing.type: Easing.InQuad
                                            duration: 50;
                                        }
                                    }
                                    ParallelAnimation {
                                        NumberAnimation {
                                            property: "scale";
                                            from: 15;
                                            to: 1.0;
                                            duration: 300
                                        }
                                        NumberAnimation {
                                            property: "x";
                                            from: mycode.width / 2;
                                            easing.type: Easing.OutQuad
                                            duration: 300;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Label {
                        id: labelcountdown
                        text: "--"
                        width: parent.width
                        horizontalAlignment: Text.AlignRight
                        fontSize: "x-small"
                        visible: false
                    }

                    Label {
                        id: labelgive
                        objectName: "labelgive"
                        wrapMode: Text.Wrap
                        width: parent.width
                        text: i18n.tr("When you meet someone else and want to swap, you can...")
                    }

                    Button {
                        id: buttongive
                        objectName: "buttongive"
                        width: parent.width
                        enabled: state == ""

                        text: i18n.tr("Get a code to give them")

                        onClicked: {
                            root.getCode();
                        }
                        states: [
                            State {
                                name: ""
                                PropertyChanges { target: buttongive; text: i18n.tr("Get a code to give them") }
                            },
                            State {
                                name: "error"
                                PropertyChanges { target: buttongive; text: i18n.tr("Connection error") }
                            }
                        ]

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
            title: i18n.tr("Winnings") + " (" + (identifiers.documents.length || 0) + ")"
            page: Page {
                Column {
                    id: "col2"
                    spacing: units.gu(1)
                    anchors {
                        margins: units.gu(2)
                        fill: parent
                    }

                    Label {
                        text: "Identifiers you have found"
                    }
                    Label {
                        text: identifiers.documents.length;
                    }

                    GridLayout {
                        columns: 3
                        columnSpacing: units.gu(0.5)
                        Repeater {
                            model: identifiers
                            Face {
                                width: (col2.width - units.gu(1)) / 3
                                height: (col2.width - units.gu(1)) / 3
                                identifier: model.contents.identifier
                            }
                        }
                    }


                }
            }
        }
    }
}
