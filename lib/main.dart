import 'dart:convert';

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BOMつけるくん',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: AppBarTheme(
          titleTextStyle: TextStyle(
            color: Colors.white, // タイトル文字の色を変更
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          backgroundColor: Colors.blue, // AppBarの背景色
          iconTheme: IconThemeData(
            color: Colors.white, // アイコンの色
          ),
        ),
      ),
      home: const MyHomePage(title: 'BOMつけるくん'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  bool pickSuccess = false; // 読み込みが成功したら true

  late File file;
  late String fileName = "ファイルが選択されていません";
  late String fileContents;
  String? _directoryPath = "出力ディレクトリが選択されていません";
  double _value = 0;
  bool executing = false;//実行中か
  bool fileWrote = false; // ファイル書き込みが成功したら true

  Future<void> _pickFileIsSuccess() async {
    final filePickerResult = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'], // ピックする拡張子を限定できる。
    );
    String selectFileName = '';
    if (filePickerResult != null) {
      pickSuccess = true;
      file = File(filePickerResult.files.single.path!);
      //UTF-8エンコーディングのチェックとBOMのチェック
      String? checkResult = await checkCSVFileEncoding(file);
      if(checkResult != null) {
        selectFileName = checkResult;
        pickSuccess = false;
      } else {
        selectFileName = filePickerResult.files.single.name;
        pickSuccess = true;
      }
    } else {
      pickSuccess = false;
      selectFileName = '何も選択されませんでした';
      fileContents = 'ファイルの中身がここに表示されます';
    }
    setState(() {
      fileName = selectFileName;
    });
  }

  Future<String?> checkCSVFileEncoding(File file) async {
    List<int> fileBytes = await file.readAsBytes();

    // BOMのチェック
    bool hasBOM = fileBytes.length >= 3 &&
        fileBytes[0] == 0xEF &&
        fileBytes[1] == 0xBB &&
        fileBytes[2] == 0xBF;

    // UTF-8エンコーディングのチェック
    try {
      Utf8Decoder().convert(fileBytes);
    } catch (e) {
      return 'ファイルの文字コードがUTF-8ではありません。';
    }

    if (hasBOM) {
      return 'このファイルにはBOMがすでに含まれています。';
    }
    return null;
  }

  void _selectFolder() {
    FilePicker.platform.getDirectoryPath().then((value) {
      setState(() => _directoryPath = value);
    });
  }

  Future<void> _attachBomFile() async {
    setState(() {
      _value = 0;
      executing = true;
      fileWrote = false;
    });

    if (file == null) {
      print('ファイルが選択されていません。');
      setState(() {
        executing = false;
      });
      return;
    }

    if (!file!.existsSync()) {
      print('指定したファイルが存在しません。');
      setState(() {
        executing = false;
      });
      return;
    }

    int linesWritten = 0;
    int allLines = 0;
    IOSink? outputSink;

    try {
      // 全行数をカウント
      allLines = await _countLines(file);

      // 入力ファイルを再度開く
      Stream<String> inputLines = file.openRead().transform(utf8.decoder).transform(LineSplitter());

      outputSink = await _createNewOutputSink();

      await for (var line in inputLines) {
        outputSink.writeln(line);
        linesWritten++;
        setState(() {
          _value = linesWritten / allLines;
        });
      }
      await _closeSink(outputSink); // ファイルを閉じる
      //ファイル閉じたら、_valueを1にする
      setState(() {
        _value = 1;
        executing = false;
      });
      print('BOMの付与が完了しました。');
    } catch (e) {
      print('エラーが発生しました: $e');
      setState(() {
        executing = false;
      });
    }
  }

  Future<int> _countLines(File file) async {
    int count = 0;
    await for (var _ in file.openRead().transform(utf8.decoder).transform(LineSplitter())) {
      count++;
    }
    return count;
  }

  Future<IOSink> _createNewOutputSink() async {
    String outputFilePath = '$_directoryPath/utf8_bom.csv';
    File outputFile = File(outputFilePath);
    IOSink sink = outputFile.openWrite();
    // UTF-8 BOM
    sink.add([0xEF, 0xBB, 0xBF]);
    return sink;
  }

  Future<void> _closeSink(IOSink? sink) async {
    if (sink != null) {
      await sink.flush();
      await sink.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (executing) ...[
                CircularProgressIndicator(), // ローディングインジケーターを追加
                SizedBox(height: 16),
                LinearProgressIndicator(
                  minHeight: 20,
                  value: _value,
                ),
                SizedBox(height: 8),
                Text(_value == 1 ? (fileWrote ? "COMPLETE!!" : "ファイル書き込み中...") : "処理中..."),
              ] else ...[
                Card(
                  elevation: 4.0,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          "使い方",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text("BOMつけるくんは、指定したUTF-8のCSVファイルにBOMを付与するツールです。BOMがついているUTF-8のCSVはExcelで開いても文字化けしなくなります。"),
                        Text("BOMをつける対象のUTF-8のCSVファイル、結果のファイルを出力するディレクトリを入力したら、BOM付与ボタンを押してください。出力されるファイルはutf8_bom.csv で出力されます。"),
                        SizedBox(height: 8),
                        Text("ファイルの文字コードはUTF-8である必要があります。あと、すでにBOMがついている場合は、BOM付与ボタンは押せません。"),

                      ],
                    ),
                  ),
                ),
                Card(
                  elevation: 4.0,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: <Widget>[
                        ElevatedButton(
                          onPressed: executing ? null : _pickFileIsSuccess,
                          child: Text("CSVファイル選択"),
                        ),
                        SizedBox(height: 8),
                        Text("BOMを付与するCSVファイル：$fileName"),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: executing ? null : _selectFolder,
                          child: Text("出力ディレクトリ選択"),
                        ),
                        SizedBox(height: 8),
                        Text("出力するディレクトリ：${_directoryPath ?? ""}"),
                        SizedBox(height: 16),
                        LinearProgressIndicator(
                          minHeight: 20,
                          value: _value,
                        ),
                        SizedBox(height: 8),
                        Text(_value == 1 ? "COMPLETE!!" : ""),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: (executing || fileName.isEmpty || _directoryPath == null || _directoryPath! == "出力ディレクトリが選択されていません" || !pickSuccess)
                              ? null
                              : _attachBomFile,
                          child: Text("BOM付与"),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
