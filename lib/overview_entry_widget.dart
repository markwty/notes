import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'overview_entry.dart';
import 'graphview_page.dart';

class OverviewEntryWidget extends StatefulWidget {
  final OverviewEntry item;
  final void Function(int) onClick;
  final bool selected;

  OverviewEntryWidget({
    Key key, @required this.item, this.onClick, this.selected: false})
      : assert(item != null),
        assert(selected != null),
        super(key: key);

  @override
  _OverviewEntryWidgetState createState() => _OverviewEntryWidgetState();
}

class _OverviewEntryWidgetState extends State<OverviewEntryWidget> {
  TextEditingController titleController;
  TextEditingController descriptionController;
  bool isEditingTitle = false;
  bool isEditingDescription = false;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.item.title);
    descriptionController = TextEditingController(text: widget.item.description);
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleField =
    (isEditingTitle)?
    Center(
      child: TextField(
        onSubmitted: (newValue) {
          setState(() {
            isEditingTitle = false;
            DatabaseHelper dbHelper = new DatabaseHelper(TABLE_NAME: "overview_table");
            dbHelper.updateData("${widget.item.iid}", [newValue, widget.item.description, widget.item.datetime]).then((success) {
              dbHelper.close();
            });
          });
        },
        autofocus: true,
        controller: titleController,
      ),
    )
        : InkWell(
        onTap: () {
          setState(() {
            isEditingTitle = true;
          });
        },
        child: Text(
            titleController.text,
            style: (widget.selected)? TextStyle(color: Colors.blueAccent, fontSize: 18.0):
            TextStyle(color: Colors.black, fontSize: 18.0)
        )
    );

    final descriptionField =
    (isEditingDescription)?
    Center(
      child: TextField(
        onSubmitted: (newValue) {
          setState(() {
            isEditingDescription = false;
            DatabaseHelper dbHelper = new DatabaseHelper(TABLE_NAME: "overview_table");
            dbHelper.updateData("${widget.item.iid}", [widget.item.title, newValue, widget.item.datetime]).then((success){
              dbHelper.close();
            });
          });
        },
        autofocus: true,
        controller: descriptionController,
      ),
    )
        : InkWell(
        onTap: () {
          setState(() {
            isEditingDescription = true;
          });
        },
        child: Text(
            descriptionController.text,
            style: (widget.selected)? TextStyle(color: Colors.blueAccent, fontSize: 18.0):
            TextStyle(color: Colors.black, fontSize: 18.0)
        )
    );

    return Padding(
      padding: const EdgeInsets.all(2.0),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: (){Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => GraphViewPage(iid: widget.item.iid)),
            );
          },
          onLongPress:(){(widget.onClick)?.call(widget.item.iid);},
          child:
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child:
                    Container(
                      margin: const EdgeInsets.all(5.0),
                      height: 100,
                      width: MediaQuery.of(context).size.width / 1.5,
                      decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.all(Radius.circular(20))
                      ),
                      child:
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Expanded(
                              flex: 2,
                              child:
                                Padding(
                                  padding: EdgeInsets.only(top:5.0),
                                  child:
                                    Container(
                                      alignment: Alignment.topCenter,
                                      child: titleField
                                    )
                                )
                            ),
                            Expanded(
                                flex: 2,
                                child:
                                Container(
                                    alignment: Alignment.topCenter,
                                    child: descriptionField
                                )
                            ),
                            Expanded(
                                flex: 1,
                                child:
                                  Padding(
                                    padding: EdgeInsets.only(right:5.0),
                                    child:
                                      Container(
                                          alignment: Alignment.topCenter,
                                          child: Align(alignment: Alignment.centerRight, child: Text(widget.item.datetime))
                                      )
                                  )
                            )
                          ]
                        )
                    )
                )
              ]
            )
        )
    );
  }
}