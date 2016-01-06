import QtQuick 2.2

import "theme/theme.js" as T

/*

  We expect identifier to be an md5hash:
  3727b8ced73aebd3cf50e67050deac53

  The first characters are treated, one by one, as a single hex digit, and then applied
  to the parts of the face, in order, modded with the total number of possibilities for that
  facepart as found in T.themedetails. So Head is first, and there are 8 heads, then a hex digit
  A (==10) counts as face 2 (10 % 8 == 2) which is in theme/Face/2.svg.

  Faceparts in order: Head, Ears, Beard, Mouth, Nose, Eyes, Eyebrows, Hair, Glasses, Accessories, Hat
  Some faceparts are optional: if one of these comes up 0, then we don't include it.
  Optional faceparts: Beard, Accessories, Hair, Glasses

  That takes up 11 chars. The next 6 are used as a background colour for the rectangle.

*/
Rectangle {
    id: root
    property string identifier
    color: root.getColour()

    function getColour() {
        var c = "#" + root.identifier.substring(11,16);
        console.log(c);
        return c;
    }

    function getFaceParts() {
        var r = [];
        var fps = "Head,Ears,Beard,Mouth,Nose,Eyes,Eyebrows,Hair,Glasses,Accessories,Hat".split(",");
        var optionals = "Beard,Accessories,Hair,Glasses".split(",");
        for (var i=0; i<fps.length; i++) {
            var fp = fps[i];
            var v = parseInt(root.identifier.charAt(i), 16);
            v = v % T.themedetails[fp];
            if (optionals.indexOf(fp) !== -1 && v == 0) { continue; }

            r.push({part: fp, number: v});
        }
        return r;
    }

    ListModel {
        id: m
    }

    Repeater {
        model: m
        Image {
            source: "theme/" + model.part + "/" + model.number + ".svg"
            anchors.fill: parent
            fillMode: Image.PreserveAspectFit
        }
    }

    Component.onCompleted: {
        root.getFaceParts().forEach(function(fp) {
            m.append(fp);
        })
    }
}

