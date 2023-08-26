import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_html_to_pdf/flutter_html_to_pdf.dart';
import 'package:flutter_mobile_vision/flutter_mobile_vision.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quill_delta/quill_delta.dart';
import 'package:share/share.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zefyr/zefyr.dart';

import 'database_helper.dart';
import 'file_utils.dart';
import 'markdown.dart' as nmd;
import 'zefyr/images.dart';

class NotesPage extends StatefulWidget {
  final void Function(String) onSave;
  String subtitle, content;
  final List<NotusChange> saves = [];

  NotesPage({this.subtitle: "", this.content: "", @required this.onSave});
  @override
  _NotesPageState createState() => _NotesPageState();
}

Delta getDelta(String content) {
  if (content == "") {
    content = r'[{"insert":"Welcome"},{"insert":"\n","attributes":{"heading":1}}]';
  }
  return Delta.fromJson(json.decode(content) as List);
}

enum _Options {darkTheme, ocr, niv, esv, share}

class _NotesPageState extends State<NotesPage> {
  ZefyrController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _editing = false;
  StreamSubscription<NotusChange> _sub;
  bool _darkTheme = false;
  int currSave = -1;
  bool ignore = false;
  List<OcrText> texts = [];

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      setState(() {
        _darkTheme = prefs.getBool("dark theme") ?? false;
      });
    });
    _controller = ZefyrController(NotusDocument.fromDelta(getDelta(widget.content)));
    _sub = _controller.document.changes.listen((change) {
      if (ignore) {
        ignore = false;
        return;
      }
      widget.saves.removeRange(currSave + 1, widget.saves.length);
      widget.saves.add(change);
      if (widget.saves.length >= 10) {
        widget.saves.removeAt(0);
      } else {
        currSave++;
      }
    });
  }

  @override
  void dispose() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool("dark theme", _darkTheme);
    });
    _sub.cancel();
    super.dispose();
  }

  void save() {
    final String contents = jsonEncode(_controller.document);
    widget.onSave?.call(contents);
  }

  List<int> parseString(String query) {
    int start_chapter = -1;
    int end_chapter = -1;
    int start_verse = -1;
    int end_verse = -1;
    if (query.indexOf('-') != -1) {
      if (query.indexOf(':') != -1) {
        int loc = query.indexOf("-");
        String startString = query.substring(0, loc);
        String endString = query.substring(loc + 1);
        if (endString.indexOf(':') == -1) {
          loc = startString.indexOf(":");
          start_chapter = int.parse(startString.substring(0, loc));
          start_verse = int.parse(startString.substring(loc + 1));
          end_chapter = start_chapter;
          end_verse = int.parse(endString);
        } else {
          loc = startString.indexOf(":");
          start_chapter = int.parse(startString.substring(0, loc));
          start_verse = int.parse(startString.substring(loc + 1));
          loc = endString.indexOf(":");
          end_chapter = int.parse(endString.substring(0, loc));
          end_verse = int.parse(endString.substring(loc + 1));
        }
      } else {
        int loc = query.indexOf("-");
        start_chapter = int.parse(query.substring(0, loc));
        end_chapter = int.parse(query.substring(loc + 1));
        start_verse = 1;
        end_verse = 100;//pseudo
      }
    } else {
      if (query.indexOf(':') != -1) {
        int loc = query.indexOf(":");
        start_chapter = int.parse(query.substring(0, loc));
        start_verse = int.parse(query.substring(loc + 1));
        end_verse = start_verse;
      } else {
        start_chapter = int.parse(query);
        start_verse = 1;
        end_verse = 100;//pseudo
      }
      end_chapter = start_chapter;
    }
    return [start_chapter, start_verse, end_chapter, end_verse];
  }

  void autoCompleteVerses(String version) async {
    String text = _controller.selection.textInside(_controller.document.toPlainText());
    int loc = text.lastIndexOf(' ');
    if (loc == -1) {
      return;
    }
    String query = text.substring(loc + 1);
    String book = text.substring(0, loc);
    List<int> attributes = parseString(query);
    int c1 = attributes[0];
    int v1 = attributes[1];
    int c2 = attributes[2];
    int v2 = attributes[3];

    DatabaseHelper dbHelper;
    List<Map> res;
    if (version == "NIV") {
      dbHelper = DatabaseHelper(
          TABLE_NAME: "Bible", DATABASE_NAME: "niv");
      res = await dbHelper.getAllVersesNIV(book.toLowerCase(), c1, v1, c2, v2);
    } else {
      dbHelper = DatabaseHelper(TABLE_NAME: "Chapter", DATABASE_NAME: "esv");
      res = await dbHelper.getAllVersesESV(book.toLowerCase(), c1, v1, c2, v2);
    }
    String output = "";
    try {
      if (res.length == 0) {
        Fluttertoast.showToast(
            msg: "Verse/s not found",
            toastLength: Toast.LENGTH_SHORT,
            timeInSecForIosWeb: 1
        );
      } else {
        for (int i = 0; i < res.length; i++) {
          output += "\n" + "${res[i]['Number']} " + res[i]["Text"];
        }
      }
    } catch(e) {
      print("$runtimeType: $e");
      dbHelper.close();
      return;
    }
    dbHelper.close();
    _controller.replaceText( _controller.selection.end, 0, output);
  }

  void searchVerses(String version) async {
    String query = _controller.selection.textInside(_controller.document.toPlainText());

    DatabaseHelper dbHelper;
    List<Map> res;
    if (version == "NIV") {
      dbHelper = DatabaseHelper(
          TABLE_NAME: "Bible", DATABASE_NAME: "niv");
      res = await dbHelper.searchVersesNIV(query);
    } else {
      dbHelper = DatabaseHelper(TABLE_NAME: "Chapter", DATABASE_NAME: "esv");
      res = await dbHelper.searchVersesESV(query);
    }
    String output = "";
    try {
      if (res.length == 0) {
        Fluttertoast.showToast(
            msg: "No verse/s found",
            toastLength: Toast.LENGTH_SHORT,
            timeInSecForIosWeb: 1
        );
      } else {
        for (int i = 0; i < res.length; i++) {
          output += "\n" + "${res[i]['BookName']} ${res[i]['ChapterNumber']}:${res[i]['Number']} " + res[i]["Text"];
        }
      }
    } catch(e) {
      print("$runtimeType: $e");
      dbHelper.close();
      return;
    }
    dbHelper.close();
    _controller.replaceText( _controller.selection.end, 0, output);
  }

  Future<Null> _read() async {
    texts = [];
    try {
      texts = await FlutterMobileVision.read(
        multiple: true,
        camera: FlutterMobileVision.CAMERA_BACK,
        waitTap: true,
      );
    } on Exception {
      texts.add(OcrText('Fail'));
    }

    if (!mounted) return;
  }

  void setOCR() {
    String ocrString = "";
    for (int i = 0; i < texts.length; i++) {
      ocrString += texts[i].value + " ";
    }
    ocrString = ocrString.trim();
    if (ocrString == "Fail" || ocrString == "") {
      Fluttertoast.showToast(
          msg: "Failed to recognise text",
          toastLength: Toast.LENGTH_SHORT,
          timeInSecForIosWeb: 1
      );
      return;
    }
    setState(() {
      _controller.replaceText(_controller.selection.end, 0, ocrString);
    });
  }

  void shareFile(BuildContext context) {
    final Converter<Delta, String> notusHTML = nmd.NotusMarkdownCodec().encoder;
    String markdown;
    try {
      markdown = notusHTML.convert(_controller.document.toDelta());
    } catch(error) {
      Fluttertoast.showToast(
          msg: "Conversion failed. (Line divider & images are not supported)",
          toastLength: Toast.LENGTH_SHORT,
          timeInSecForIosWeb: 1
      );
      return;
    }
    int start = 0;
    bool odd = true;
    while (true) {
      int index = markdown.indexOf("_**", start);
      if (index == -1) {
        break;
      }

      start = index + 1;
      if (odd) {
        markdown = markdown.replaceRange(index, index + 3, "#%^");
      }
      odd = !odd;
    }
    odd = true;
    start = 0;
    while (true) {
      int index = markdown.indexOf("**_", start);
      if (index == -1) {
        break;
      }

      start = index + 1;
      if (odd) {
        markdown = markdown.replaceRange(index, index + 3, "#%^");
      } else {
        markdown = markdown.replaceRange(index, index + 3, "_**");
      }
      odd = !odd;
    }
    //markdown = markdown.replaceAll("\n#%^", "\n**_");
    //markdown = markdown.replaceAll("#%^", " **_");
    markdown = markdown.replaceAll("#%^", "**_");

    String html = md.markdownToHtml(markdown);
    bool blockquote = false;
    String html2 = "";
    LineSplitter.split(html).forEach((line) {
      if (line == "<blockquote>") {
        blockquote = true;
        html2 += line + "\n";
        return;
      } else if (line == "</blockquote>") {
        blockquote = false;
      }
      if (blockquote) {
        if(!line.startsWith("<p>")) {
          line = "<p>" + line;
        }
        if(!line.endsWith("</p>")) {
          line += "</p>";
        }
      }
      html2 += line + "\n";
    });

    bool code = false;
    html = "";
    String content = "";
    LineSplitter.split(html2).forEach((line) {
      if (line.startsWith("<pre><code>")) {
        code = true;
        html += "<pre><code>\n";
        content += line.substring("<pre><code>".length) + "\n";
        return;
      } else if (line == "</code></pre>") {
        html += md.markdownToHtml(content) + "\n";
        content = "";
        code = false;
      }
      if (code) {
        content += line + "\n";
      } else {
        html += line + "\n";
      }
    });
    print(html);

    if (context != null) {
      final RenderBox box = context.findRenderObject();
      getApplicationDocumentsDirectory()
          .then((documentsDirectory) async {
        String path = join(documentsDirectory.path, "output.pdf");
        await FlutterHtmlToPdf.convertFromHtmlContent(
            html, documentsDirectory.path, "output");
        if (await FileUtils.checkPath(path)) {
          await Share.shareFiles([path], sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size);
        }
      });
    }
  }

  void handlePopupItemSelected(value) {
    if (!mounted) return;
    switch (value) {
      case _Options.darkTheme:
        setState(() {
          _darkTheme = !_darkTheme;
        });
        break;
      case _Options.ocr:
        _read().then((value){
          setOCR();
        });
        break;
      case _Options.niv:
        SharedPreferences.getInstance().then((prefs) {
          prefs.setString("bible version", "NIV");
        });
        break;
      case _Options.esv:
        SharedPreferences.getInstance().then((prefs) {
          prefs.setString("bible version", "ESV");
        });
        break;
      case _Options.share:
        break;
    }
  }

  List<PopupMenuEntry<_Options>> buildPopupMenu(BuildContext context) {
    return [
      CheckedPopupMenuItem(
        value: _Options.darkTheme,
        child: Text("Dark theme"),
        checked: _darkTheme
      ),
      PopupMenuItem(
        value: _Options.ocr,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Icon(Icons.camera),
            Text("Image to text")
          ])
      ),
      PopupMenuItem(
        value: _Options.niv,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Icon(Icons.sort_by_alpha),
            Text("NIV")
          ])
      ),
      PopupMenuItem(
        value: _Options.esv,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Icon(Icons.sort_by_alpha),
            Text("ESV")
          ])
      ),
      PopupMenuItem(
        value: _Options.share,
        child: Builder(
          builder: (BuildContext context) {
            return
              FlatButton(
                child:
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Icon(Icons.share),
                      Text("Share")
                    ]
                  ),
                onPressed: () => shareFile(context),
              );
          }
        )
      ),
    ];
  }

  void _startEditing() {
    setState(() {
      _editing = true;
    });
  }

  void _stopEditing() {
    setState(() {
      _editing = false;
      save();
    });
  }

  @override
  Widget build(BuildContext context) {
    final done = _editing
        ? IconButton(onPressed: _stopEditing, icon: Icon(Icons.save))
        : IconButton(onPressed: _startEditing, icon: Icon(Icons.edit));
    final result = Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(widget.subtitle),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            save();
            Navigator.of(context).pop();
          },
        ),
        actions: [
          done,
          IconButton(
              icon: Icon(Icons.undo),
              onPressed: (currSave >= 0)? () {
                ignore = true;
                NotusChange notusChange = widget.saves[currSave];
                _controller.compose(notusChange.change.invert(notusChange.before));
                setState(() {
                  currSave -= 1;
                });
              }: null
          ),
          IconButton(
              icon: Icon(Icons.redo),
              onPressed: (widget.saves.length > currSave + 1)? () {
                ignore = true;
                _controller.compose(widget.saves[currSave + 1].change);
                setState(() {
                  currSave += 1;
                });
              }: null
          ),
          PopupMenuButton<_Options>(
            itemBuilder: buildPopupMenu,
            onSelected: handlePopupItemSelected,
          ),
          IconButton(
              icon: Icon(Icons.sort_by_alpha),
              onPressed: () {
                SharedPreferences.getInstance().then((prefs) {
                  String version = prefs.getString("bible version") ?? "NIV";
                  autoCompleteVerses(version);
                });
              }
          ),
          IconButton(
              icon: Icon(Icons.book),
              onPressed: () {
                SharedPreferences.getInstance().then((prefs) {
                  String version = prefs.getString("bible version") ?? "NIV";
                  searchVerses(version);
                });
              }
          ),
        ],
      ),
      body:
      ZefyrScaffold(
        child: ZefyrEditor(
          controller: _controller,
          focusNode: _focusNode,
          mode: _editing ? ZefyrMode.edit : ZefyrMode.select,
          imageDelegate: CustomImageDelegate(),
          keyboardAppearance: _darkTheme ? Brightness.dark : Brightness.light,
        ),
      ),
    );

    if (_darkTheme) {
      return Theme(data: ThemeData.dark(), child: result);
    }
    return Theme(data: ThemeData(primarySwatch: Colors.cyan), child: result);
  }
}
