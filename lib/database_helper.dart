import 'dart:async';
import 'dart:io' as io;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static Database _db;
  final String DATABASE_NAME;
  String TABLE_NAME;
  List<String> COL_NAMES;
  final String extension;

  static Map<String, List<String>> tableColumnsMap = {
    "overview_table": ["Title", "Description", "Datetime"],
    "Book": ["Name", "Id"],
    "Chapter": ["Id", "BookId", "Number"],
    "Verse": ["Text", "Id", "Number", "ChapterId"],
    "Bible": ["Book", "Chapter", "Verse", "Text"]
  };

  DatabaseHelper({this.TABLE_NAME, this.DATABASE_NAME: "notes", this.extension: "db"}) {
    if (tableColumnsMap.containsKey(TABLE_NAME)) {
      this.COL_NAMES = tableColumnsMap[TABLE_NAME];
    }
    db;
  }

  Future<Database> get db async {
    if (_db != null) return _db;
    _db = await initDatabase();
    onCreate(_db, 1);
    return _db;
  }

  Future<Database> initDatabase() async {
    io.Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, DATABASE_NAME + ".$extension");
    Database theDb;
    if (tableColumnsMap.containsKey(TABLE_NAME)) {
      theDb = await openDatabase(path, version: 1, onCreate: onCreate);
    } else {
      theDb = await openDatabase(path, version: 1, onCreate: null);
    }
    return theDb;
  }

  void killDatabase() async{
    io.Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, DATABASE_NAME + ".$extension");
    await deleteDatabase(path);
  }

  Future close() async {
    if (_db != null) {
      _db.close();
      _db = null;
    }
  }

  void onCreate(Database db, int version) async {
    //Create table for the first time for storage within phone
    StringBuffer query = new StringBuffer();
    query.write("CREATE TABLE IF NOT EXISTS " + TABLE_NAME +" (ID INTEGER PRIMARY KEY AUTOINCREMENT");
    for (var i = 0; i < COL_NAMES.length; i++) {
      query.write(", ");
      query.write(COL_NAMES[i]);
      query.write(" TEXT");
    }
    query.write(")");
    await db.execute(query.toString());
  }

  Future printAllData() async{
    List<Map> res = await (await this.db).rawQuery("SELECT * FROM " + TABLE_NAME);
    if (res.length == 0) {
      print("$runtimeType: Nothing to display");
    } else {
      for (int i = 0; i < res.length; i++) {
        print(res[i]);
      }
    }
  }

  Future<void> getTableNames() async {
    (await (await this.db).query('sqlite_master', columns: ['type', 'name'])).forEach((row) {
      print(row.values);
    });
  }

  Future<List<Map>> getAllVersesESV(String book, int c1, int v1, int c2, int v2) async{
    return (await this.db).rawQuery(
        """SELECT Verse.Number, Verse.Text FROM Book, Chapter, Verse WHERE LOWER(Book.Name)='$book' AND Book.Id = Chapter.BookId AND Chapter.Id = Verse.ChapterId
        AND (Chapter.Number,Verse.Number) >= ($c1,$v1) AND (Chapter.Number,Verse.Number) <= ($c2,$v2) order by Chapter.Number, Verse.Number""");
  }

  Future<List<Map>> searchVersesESV(String query) async{
    return (await this.db).rawQuery(
        """SELECT Book.Name as BookName, Chapter.Number as ChapterNumber, Verse.Number, Verse.Text FROM Verse WHERE Verse.Text LIKE '%$query%' LIMIT 5""");
  }

  Future<List<Map>> getAllVersesNIV(String book, int c1, int v1, int c2, int v2) async{
    return (await this.db).rawQuery(
        """SELECT Verse as Number, Text FROM Bible WHERE LOWER(Book)='$book' AND (Chapter,Verse) >= ($c1,$v1) AND (Chapter,Verse) <= ($c2,$v2) order by Chapter, Verse""");
  }

  Future<List<Map>> searchVersesNIV(String query) async{
    return (await this.db).rawQuery(
        """SELECT Book as BookName, Chapter as ChapterNumber, Verse as Number, Text FROM Bible WHERE Text LIKE '%$query%' LIMIT 5""");
  }

  Future<List<Map>> getAllData() async{
    return (await this.db).rawQuery("SELECT * FROM " + TABLE_NAME);
  }

  Future<List<Map>> getData(int id, List<String> cols) async{
    String colsName = cols.join(",");
    return (await this.db).rawQuery("SELECT $colsName FROM " + TABLE_NAME + " WHERE ID = $id");
  }

  Future<int> getRowCount() async{
    int count = Sqflite.firstIntValue(await (await this.db).rawQuery("SELECT COUNT(*) FROM " + TABLE_NAME));
    return count;
  }

  Future<bool> insertData(String id, List<String> values) async {
    Map<String, String> contentValues = new Map<String, String>();
    contentValues["ID"] = id;
    for (int i = 0; i < COL_NAMES.length; i++) {
      contentValues[COL_NAMES[i]] = values[i];
    }
    return await (await this.db).insert(TABLE_NAME, contentValues) != null;
  }

  Future<int> insertDataAutoID(List<String> values) async {
    Map<String, String> contentValues = new Map<String, String>();
    for (int i = 0; i < COL_NAMES.length; i++) {
      contentValues[COL_NAMES[i]] = values[i];
    }
    return await (await this.db).insert(TABLE_NAME, contentValues);
  }

  Future<bool> updateDataSelected(String id, List<String> values, List<String> colNames) async{
    Map<String, String> contentValues = new Map<String, String>();
    for (int i = 0; i < colNames.length; i++) {
      contentValues[colNames[i]] = values[i];
    }
    return await (await this.db).update(TABLE_NAME, contentValues, where: 'ID = ?', whereArgs: [id]) == 1;
  }

  Future<bool> updateData(String id, List<String> values) async{
    Map<String, String> contentValues = new Map<String, String>();
    for (int i = 0; i < COL_NAMES.length; i++) {
      contentValues[COL_NAMES[i]] = values[i];
    }
    return await (await this.db).update(TABLE_NAME, contentValues, where: 'ID = ?', whereArgs: [id]) == 1;
  }

  Future<bool> deleteData(String id) async{
    return await (await this.db).delete(TABLE_NAME, where: 'ID = ?', whereArgs: [id]) == 1;
  }

  Future<bool> IDExist(String id) async {
    int count = Sqflite.firstIntValue(await (await this.db).rawQuery("SELECT COUNT(*) FROM $TABLE_NAME WHERE ID=$id"));
    return count == 1;
  }
}