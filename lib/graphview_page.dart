import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:graphview/GraphView.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'edge_item.dart';
import 'file_utils.dart';
import 'node_item.dart';

class GraphViewPage extends StatefulWidget {
  final int iid;
  GraphViewPage({Key key, @required this.iid}): super(key: key);

  @override
  _GraphViewPageState createState() => _GraphViewPageState();
}

class _GraphViewPageState extends State<GraphViewPage> {
  bool showSettings = false;
  String orientation;
  Map<String, int> orientationMap = {"Top to Bottom": 1, "Bottom to Top": 2, "Left to Right": 3, "Right to Left": 4};
  Map<int, String> orientationReverseMap = {1: "Top to Bottom", 2: "Bottom to Top", 3: "Left to Right", 4: "Right to Left"};
  final Graph graph = Graph();
  BuchheimWalkerConfiguration builder = BuchheimWalkerConfiguration();
  List<NodeItem> graphNodes = [];
  Map<int, int> selectionMap = {};
  int selectedNode = -1;
  bool started = false;


  void setSelected(int id, BuildContext context) {
    if (selectionMap.containsKey(id)) {
      if (selectedNode >= 0 && selectedNode < graphNodes.length && graphNodes[selectedNode] != null) {
        NodeItem nodeItem = graph.getNodeAtUsingData(graphNodes[selectedNode]).data as NodeItem;
        nodeItem.selected = false;
        nodeItem.key.currentState?.setState(() {nodeItem.key.currentState.isEditingTitle = false;});
      }
      selectedNode = selectionMap[id];
      NodeItem nodeItem = graph.getNodeAtUsingData(graphNodes[selectedNode]).data as NodeItem;
      nodeItem.selected = true;
      nodeItem.key.currentState?.setState(() {});
    }
  }

  int n = 0;
  Widget getNodeText() {
    return NodeItem(key: GlobalKey(), id: n++, onTap: setSelected, onSave: save);
  }

  Future<List<NodeItem>> parseNodes(int iid) async {
    String fileContent = await FileUtils().getJson("nodes", "$iid");
    if (fileContent == "" || fileContent == "[]") {
      return null;
    }
    final parsed = jsonDecode(fileContent).cast<Map<String, dynamic>>();
    return parsed.map<NodeItem>((json) => NodeItem.fromJson(json, setSelected, save)).toList();
  }

  Future<List<EdgeItem>> parseEdges(int iid) async {
    String fileContent = await FileUtils().getJson("nodes", "${iid}_");
    if (fileContent == "" || fileContent == "[]") {
      return null;
    }
    final parsed = jsonDecode(fileContent).cast<Map<String, dynamic>>();
    return parsed.map<EdgeItem>((json) => EdgeItem.fromJson(json)).toList();
  }

  Future<void> save() async {
    List<NodeItem> nodes = graph.nodes.map((node) => node.data as NodeItem).toList();
    String nodesEncoded = jsonEncode(nodes);
    bool success = await FileUtils().saveJson(nodesEncoded, "nodes", "${widget.iid}");
    if (!success) {
      print("$runtimeType: Failed to write nodes");
      return;
    }
    List<EdgeItem> edges = graph.edges.map((edge) =>
        EdgeItem(start: (edge.source.data as NodeItem).id,
                 end: (edge.destination.data as NodeItem).id)).toList();
    String edgesEncoded = jsonEncode(edges);
    success = await FileUtils().saveJson(edgesEncoded, "nodes", "${widget.iid}_");
    if (!success) {
      print("$runtimeType: Failed to write edges");
      return;
    }
  }

  @override
  void initState() {
    super.initState();
    parseNodes(widget.iid).then((nodes) {
      if (nodes == null) {
        NodeItem nodeItem = getNodeText();
        selectionMap[nodeItem.id] = 0;
        Node node = Node(nodeItem);
        graphNodes.add(nodeItem);
        graph.addNode(node);
        setState(() {
          started = true;
        });
      } else {
        for (int i = 0; i < nodes.length; i++) {
          int id = nodes[i].id;
          if (id > n) {
            n = id;
          }
          selectionMap[id] = i;
          Node node = Node(nodes[i]);
          graphNodes.add(nodes[i]);
          graph.addNode(node);
        }
        n++;
        parseEdges(widget.iid).then((edges) {
          if (edges != null) {
            for (int i = 0; i < edges.length; i++) {
              graph.addEdge(graph.getNodeAtUsingData(graphNodes[selectionMap[edges[i].start]]),
                  graph.getNodeAtUsingData(graphNodes[selectionMap[edges[i].end]]));
            }
          }
          setState(() {
            started = true;
          });
        });
      }
    });

    SharedPreferences.getInstance().then((prefs) {
      int siblingSeparation = prefs.getInt("siblingSeparation") ?? BuchheimWalkerConfiguration.DEFAULT_SIBLING_SEPARATION;
      int levelSeparation = prefs.getInt("levelSeparation") ?? BuchheimWalkerConfiguration.DEFAULT_LEVEL_SEPARATION;
      int subtreeSeparation = prefs.getInt("subtreeSeparation") ?? BuchheimWalkerConfiguration.DEFAULT_SUBTREE_SEPARATION;
      int orientation = prefs.getInt("orientation") ?? BuchheimWalkerConfiguration.DEFAULT_ORIENTATION;
      builder
        ..siblingSeparation = siblingSeparation
        ..levelSeparation = levelSeparation
        ..subtreeSeparation = subtreeSeparation
        ..orientation = orientation;
    });
  }

  void choiceAction(String choice){
    if(choice == 'Show/hide settings') {
      showSettings = !showSettings;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: new AppBar(
            title: new Text("Notes"),
            leading: new IconButton(
              icon: new Icon(Icons.arrow_back),
              onPressed: () {
                save().then((ret) {
                  Navigator.of(context).pop();
                });
              }
            ),
            actions: <Widget>[
              PopupMenuButton<String>(
                onSelected: choiceAction,
                itemBuilder: (BuildContext context){
                  return {'Show/hide settings'}.map((String choice){
                    return PopupMenuItem<String>(
                        value: choice,
                        child: Text(choice)
                    );
                  }).toList();
                }
              ),
              IconButton(
                icon: Icon(Icons.add),
                color: Colors.black,
                onPressed: () {
                  if (selectedNode < 0 || graphNodes[selectedNode] == null) {
                    if (selectionMap.isEmpty) {
                      NodeItem nodeItem = getNodeText();
                      final Node node = Node(nodeItem);
                      selectionMap[nodeItem.id] = graphNodes.length;
                      graphNodes.add(nodeItem);
                      graph.addNode(node);
                      setState(() {});
                    } else {
                      Fluttertoast.showToast(
                          msg: "No node is selected",
                          toastLength: Toast.LENGTH_SHORT,
                          timeInSecForIosWeb: 1
                      );
                    }
                    return;
                  }

                  NodeItem nodeItem = getNodeText();
                  final Node node = Node(nodeItem);
                  selectionMap[nodeItem.id] = graphNodes.length;
                  graphNodes.add(nodeItem);
                  Node node2 = graph.getNodeAtUsingData(graphNodes[selectedNode]);
                  graph.addEdge(node2, node);
                  setState(() {
                    save();
                  });
                }
              ),
              IconButton(
                icon: Icon(Icons.remove),
                color: Colors.black,
                onPressed: () {
                  if (selectedNode < 0 || graphNodes[selectedNode] == null) {
                    Fluttertoast.showToast(
                        msg: "No node is selected",
                        toastLength: Toast.LENGTH_SHORT,
                        timeInSecForIosWeb: 1
                    );
                    return;
                  }
                  NodeItem nodeItem = graphNodes[selectedNode];
                  Node node = graph.getNodeAtUsingData(nodeItem);
                  if (graph.hasSuccessor(node)) {
                    AlertDialog alert = AlertDialog(
                      title: Text("AlertDialog"),
                      content: Text("Deleting this node means multiple deletion. Would you like to continue?"),
                      actions: [
                        TextButton(
                          child: Text("Cancel"),
                          onPressed:  () {
                            Navigator.of(context).pop();
                          }
                        ),
                        TextButton(
                          child: Text("Continue"),
                          onPressed:  () {
                            List<Node> nodes = graph.successorsOf(node);
                            for (int i = 0; i < nodes.length; i++) {
                              graph.removeNode(nodes[i]);
                              int id = (nodes[i].data as NodeItem).id;
                              graphNodes[selectionMap[id]] = null;
                              selectionMap.remove(id);
                            }
                            graph.removeNode(node);
                            graphNodes[selectedNode] = null;
                            selectionMap.remove(nodeItem.id);
                            Navigator.of(context).pop();
                            setState(() {
                              save();
                            });
                          }
                        )
                      ],
                    );
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return alert;
                      },
                    );
                    return;
                  }
                  graph.removeNode(node);
                  graphNodes[selectedNode] = null;
                  selectionMap.remove(nodeItem.id);
                  setState(() {
                    save();
                  });
                }
              )
            ]
        ),
        body: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            showSettings?
            Column(
              children: <Widget>[
                Wrap(
                  children: <Widget>[
                    Container(
                      width: 100,
                      child: TextFormField(
                        initialValue: builder.siblingSeparation.toString(),
                        decoration: InputDecoration(labelText: "Sibling Separation"),
                        keyboardType: TextInputType.number,
                        onChanged: (text) {
                          builder.siblingSeparation = int.tryParse(text) ?? 100;
                          setState(() {
                            SharedPreferences.getInstance().then((prefs) {
                              prefs.setInt("siblingSeparation", builder.siblingSeparation);
                            });
                          });
                        },
                      ),
                    ),
                    SizedBox(width:20),
                    Container(
                      width: 100,
                      child: TextFormField(
                        initialValue: builder.levelSeparation.toString(),
                        decoration: InputDecoration(labelText: "Level Separation"),
                        keyboardType: TextInputType.number,
                        onChanged: (text) {
                          builder.levelSeparation = int.tryParse(text) ?? 100;
                          setState(() {
                            SharedPreferences.getInstance().then((prefs) {
                              prefs.setInt("levelSeparation", builder.levelSeparation);
                            });
                          });
                        },
                      ),
                    )
                  ]
                ),
                Wrap(
                  children: <Widget>[
                    Container(
                      width: 100,
                      child: TextFormField(
                        initialValue: builder.subtreeSeparation.toString(),
                        decoration: InputDecoration(labelText: "Subtree Separation"),
                        keyboardType: TextInputType.number,
                        onChanged: (text) {
                          builder.subtreeSeparation = int.tryParse(text) ?? 100;
                          setState(() {
                            SharedPreferences.getInstance().then((prefs) {
                              prefs.setInt("subtreeSeparation", builder.subtreeSeparation);
                            });
                          });
                        },
                      ),
                    ),
                    Container(
                        width: 120,
                        child:
                        Column(
                            children: <Widget>[
                              Container(
                                  padding: EdgeInsets.fromLTRB(0, 5, 0, 0),
                                  child: Text(
                                    "Orientation",
                                    style: new TextStyle(fontSize: 12.0),
                                  )
                              ),
                              DropdownButton<String>(
                                value: orientationReverseMap[builder.orientation],
                                icon: Icon(Icons.arrow_downward),
                                iconSize: 16,
                                elevation: 16,
                                style: TextStyle(color: Colors.deepPurple),
                                onChanged: (String newValue) {
                                  setState(() {
                                    builder.orientation = orientationMap.containsKey(newValue)? orientationMap[newValue]:1;
                                    orientation = newValue;
                                    setState(() {
                                      SharedPreferences.getInstance().then((prefs) {
                                        prefs.setInt("orientation", builder.orientation);
                                      });
                                    });
                                  });
                                },
                                items: <String>["Top to Bottom", "Bottom to Top", "Left to Right", "Right to Left"]
                                    .map<DropdownMenuItem<String>>((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                              )
                            ]
                        )
                    )
                  ]
                )
              ]
            ): Wrap(children: <Widget>[SizedBox(height: 0)]),
            Expanded(
              child: started?
                InteractiveViewer(
                  constrained: false,
                  boundaryMargin: EdgeInsets.all(100),
                  minScale: 0.001,
                  maxScale: 5.6,
                  child: GraphView(
                    graph: graph,
                    algorithm: BuchheimWalkerAlgorithm(builder, TreeEdgeRenderer(builder)),
                    paint: Paint()
                      ..color = Colors.green
                      ..strokeWidth = 1
                      ..style = PaintingStyle.stroke,
                  )
                ):SizedBox(height: 0)
            ),
          ],
        )
    );
  }
}