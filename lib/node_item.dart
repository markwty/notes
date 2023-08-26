import 'package:flutter/material.dart';
import 'notes_page.dart';

class NodeItem extends StatefulWidget {
  final GlobalKey<_NodeItemState> key;
  final int id;
  String subtitle, content;
  bool selected = false;
  final void Function(int, BuildContext) onTap;
  final VoidCallback onSave;

  NodeItem({@required this.key, this.id, this.onTap, this.onSave, this.subtitle="", this.content = ""})
          :super(key: key);

  factory NodeItem.fromJson(Map<String, dynamic> json, void Function(int, BuildContext) onTap, VoidCallback onSave) {
    return NodeItem(
        key: GlobalKey(),
        id: json['id'] as int,
        onTap: onTap,
        onSave: onSave,
        subtitle: json['subtitle'] as String,
        content: json['content'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = id;
    data['subtitle'] = subtitle;
    data['content'] = content;
    return data;
  }

  @override
  _NodeItemState createState() => _NodeItemState();
}

class _NodeItemState extends State<NodeItem>{
  TextEditingController subtitleController;
  bool isEditingTitle = false;

  @override
  void initState() {
    super.initState();
    if (widget.subtitle == "") {
      widget.subtitle = "Node ${widget.id}";
    }
    subtitleController = TextEditingController(text: widget.subtitle);
  }

  @override
  void dispose() {
    subtitleController.dispose();
    super.dispose();
  }

  void setContent(String newContent) {
    widget.content = newContent;
  }

  Widget build(BuildContext context) {
    final subtitleField =
    (isEditingTitle)?
    Center(
      child: TextField(
        style: TextStyle(color: Colors.black),
        onSubmitted: (newValue) {
          setState(() {
            isEditingTitle = false;
            widget.subtitle = subtitleController.text;
            widget.onSave?.call();
          });
        },
        autofocus: true,
        controller: subtitleController,
      ),
    ): InkWell(
        onTap: () {
          widget.onTap?.call(widget.id, context);
          setState(() {
            isEditingTitle = true;
          });
        },
        child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                widget.selected?
                    BoxShadow(color: Colors.deepOrange[100], spreadRadius: 1)
                    : BoxShadow(color: Colors.blue[100], spreadRadius: 1),
              ],
            ),
            child: Text(
                subtitleController.text
            )
        )
    );

    return
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress:() {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => NotesPage(subtitle: widget.subtitle, content: widget.content, onSave: setContent)),
          );
        },
        child: SizedBox(
          width: 150,
          height: 80,
          child: subtitleField
        )
      );
  }
}