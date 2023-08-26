import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:instant/instant.dart';
import 'package:notes/file_utils.dart';
import 'database_helper.dart';
import 'flutter_search_bar.dart';
import 'overview_entry.dart';
import 'overview_entry_widget.dart';
import 'list_model.dart';

class OverviewPage extends StatefulWidget {
  OverviewPage({Key key}) : super(key: key);

  @override
  _OverviewPageState createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  ListModel<OverviewEntry> overviewList;
  List<OverviewEntry> fullOverviewList = [];
  int selectedId;
  SearchBar searchBar;

  _OverviewPageState() {
    searchBar = new SearchBar(
        hintText: "",
        inBar: false,
        buildDefaultAppBar: buildAppBar,
        setState: setState,
        onSubmitted: onSubmitted,
        onCleared: () {},
        onClosed: () {},
        appBarStyle: TextStyle(fontSize: 15.0, height: 2.0, color: Colors.black),
        barColor: Color.fromRGBO(255,248,220, 1),
        btnColor: Colors.black
    );
  }

  String convertTime(String datetime) {
    DateTime dt = DateFormat('yyyy-MM-dd HH:mm:ss').parse(datetime);
    DateTime convDatetime = dateTimeToOffset(offset: 8, datetime: dt);
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(convDatetime);
  }

  Future onSubmitted(String value) async {
    await updateTask();
    bool done = false;
    overviewList.clear();
    value = value.toLowerCase();
    for (int i = 0; i < fullOverviewList.length; i++) {
      OverviewEntry overviewEntry = fullOverviewList[i];
      if (overviewEntry.title.toLowerCase().contains(value)
          || overviewEntry.description.toLowerCase().contains(value)
          || convertTime(overviewEntry.datetime).toLowerCase().contains(value)) {
        done = true;
        _insert(overviewEntry);
      }
    }
    if (!done) {
      Fluttertoast.showToast(
          msg: "No result",
          toastLength: Toast.LENGTH_SHORT,
          timeInSecForIosWeb: 1
      );
    }
    setState(() {

    });
  }

  Widget _buildItem(BuildContext context, int index, Animation<double> animation) {
    return OverviewEntryWidget(
        item: overviewList[index],
        onClick: (int id) {
          setState(() {
            selectedId = (selectedId == id) ? null : id;
          });
        },
        selected: selectedId == overviewList[index].iid
    );
  }

  Widget _buildRemovedItem(OverviewEntry item, BuildContext context, Animation<double> animation) {
    return null;
  }

  void _insert(OverviewEntry entry, {int index = -1}) {
    if (index == -1) {
      index = overviewList.length;
    } else if (index < 0 || index > overviewList.length) {
      print("$runtimeType: index for inserting is out of range");
      return;
    }
    overviewList.insert(index, entry);
  }

  void _remove({int index = -1}) {
    if (index < 0 || index > overviewList.length) {
      print("$runtimeType: index for removal is out of range");
      return;
    }
    overviewList.removeAt(index);
  }

  Future<void> updateTask() async {
    DatabaseHelper dbHelper = new DatabaseHelper(TABLE_NAME: "overview_table");
    List<Map> res = await dbHelper.getAllData();
    overviewList.clear();
    try {
      if (res.length == 0) {
        print("$runtimeType: Nothing to display");
      } else {
        for (int i = 0; i < res.length; i++) {
          int iid;
          String title, description, datetime;
          iid = res[i]["ID"];
          title = res[i]["Title"];
          description = res[i]["Description"];
          datetime = res[i]["Datetime"];

          OverviewEntry overviewEntry = new OverviewEntry(
            iid: iid,
            title: title,
            description: description,
            datetime: datetime,
          );
          _insert(overviewEntry);
        }
      }
    } catch(e) {
      print("$runtimeType: $e");
      dbHelper.close();
      return;
    }
    fullOverviewList.clear();
    fullOverviewList = []..addAll(overviewList.items);
    dbHelper.close();
    setState(() {

    });
  }

  void initState() {
    super.initState();
    FileUtils.installDatabase("esv");
    FileUtils.installDatabase("niv");
    overviewList = ListModel<OverviewEntry>(
      listKey: _listKey,
      initialItems: <OverviewEntry>[],
      removedItemBuilder: _buildRemovedItem
    );
    updateTask();
  }

  Future<void> _onRefresh() async{
    updateTask();
  }

  IconButton getAddAction(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.add),
      color: Colors.black,
      onPressed: () async {
        DateTime now = DateTime.now();
        String datetime = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
        DatabaseHelper dbHelper = new DatabaseHelper(TABLE_NAME: "overview_table");
        List<String> values = ["Title", "Description", datetime];
        int iid = await dbHelper.insertDataAutoID(values);
        dbHelper.close();
        if (iid < 0 || iid == null) {
          print("$runtimeType: Entry failed to insert");
          return;
        }
        OverviewEntry overviewEntry = OverviewEntry(iid: iid, title: "title", description: "description", datetime: convertTime(datetime));
        _insert(overviewEntry);
        fullOverviewList.insert(fullOverviewList.length, overviewEntry);
      }
    );
  }

  IconButton getRemoveAction(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.remove),
      color: Colors.black,
      onPressed: () async {
        if (selectedId == null) {
          return;
        }
        DatabaseHelper dbHelper = new DatabaseHelper(TABLE_NAME: "overview_table");
        bool success = await dbHelper.deleteData("$selectedId");
        dbHelper.close();
        if (!success) {
          print("$runtimeType: Entry failed to delete");
          return;
        }
        for (int i = 0; i < overviewList.length; i++) {
          if (overviewList[i].iid == selectedId) {
            _remove(index: i);
            break;
          }
        }
        for (int i = 0; i < fullOverviewList.length; i++) {
          if (fullOverviewList[i].iid == selectedId) {
            fullOverviewList.remove(i);
            return;
          }
        }

        FileUtils fileUtils = FileUtils();
        success = await fileUtils.deleteFile("nodes", "$selectedId");
        if (!success) {
          print("Failed to delete file");
        }
        success = await fileUtils.deleteFile("nodes", "${selectedId}_");
        if (!success) {
          print("Failed to delete file");
        }
      }
    );
  }

  AppBar buildAppBar(BuildContext context) {
    return new AppBar(
        title:
        FlatButton(
            splashColor: Colors.transparent,
            onPressed: () {searchBar.getSearchAction(context).onPressed();},
            child:
            Text(
                'Click here to search...',
                style: TextStyle(fontSize: 15.0, height: 2.0, color: Colors.black)
            )
        ),
        centerTitle: true,
        backgroundColor: Color.fromRGBO(255,248,220, 1),
        elevation: 10.0,
        actions: [searchBar.getSearchAction(context), getAddAction(context), getRemoveAction(context)]
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: searchBar.build(context),
      body:
      Container(
        alignment: Alignment.center,
        child: RefreshIndicator(
            onRefresh: _onRefresh,
            child: AnimatedList(
                key: _listKey,
                initialItemCount: 0,
                itemBuilder: _buildItem
            )
        ),
      ),
    );
  }
}