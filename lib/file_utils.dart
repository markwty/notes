import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class FileUtils {
  FileUtils();

  static void installDatabase(String name, {String extension:"db"}) async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, "$name.$extension");
    if (FileSystemEntity.typeSync(path) == FileSystemEntityType.notFound){
      ByteData data = await rootBundle.load(join('assets', '$name.$extension'));
      List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await new File(path).writeAsBytes(bytes);
    }
  }

  Future<bool> saveJson(String jsonString, String directory, String iid) async {
    final Directory temp = await getTemporaryDirectory();
    final File file = File('${temp.path}/$directory/$iid.txt');
    try{
      if(!await file.exists()){
        await file.create(recursive: true);
      }
      file.writeAsString(jsonString);
    } catch(e) {
      print("$runtimeType: $e");
      return false;
    }
    return true;
  }

  Future<String> getJson(String directory, String iid) async {
    final Directory temp = await getTemporaryDirectory();
    final File file = File('${temp.path}/$directory/$iid.txt');
    try{
      if(!await file.exists()) {
        return "";
      }
      return await file.readAsString();
    } catch(e) {
      print("$runtimeType: $e");
      return "";
    }
  }

  Future<bool> deleteFile(String directory, String iid) async {
    final Directory temp = await getTemporaryDirectory();
    final File file = File('${temp.path}/$directory/$iid.txt');
    try{
      if(!await file.exists()) {
        return true;
      }
      file.delete();
      return true;
    } catch(e) {
      print("$runtimeType: $e");
      return false;
    }
  }

  static void listFilesTemp() async {
    final Directory temp = await getTemporaryDirectory();
    List contents = temp.listSync(recursive: true);
    for (var fileOrDir in contents) {
      if (fileOrDir is File) {
        print(fileOrDir.path);
      }
    }
  }

  static void listFilesDocs() async {
    final Directory docs = await getApplicationDocumentsDirectory();
    List contents = docs.listSync(recursive: true);
    for (var fileOrDir in contents) {
      if (fileOrDir is File) {
        print(fileOrDir.path);
        //print(fileOrDir.lengthSync());
      }
    }
  }

  static Future<bool> checkPath(String path) async{
    return await new File(path).exists();
  }
}