import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sqlite3/wasm.dart';

Future<WasmSqlite3> _sqlite3 = WasmSqlite3.loadFromUrl(
    Uri.parse('sqlite3.wasm')); // assume existing web/sqlite3.wasm

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late Future<CommonDatabase> db;

  void _loadDatabase(final WasmSqlite3 sqlite3, final String path,
      final Uint8List databaseBinary) {
    final fs = InMemoryFileSystem();
    sqlite3.registerVirtualFileSystem(fs, makeDefault: true);

    // borrowed by
    // https://github.com/tekartik/sqflite/blob/v2.3.0/packages_web/sqflite_common_ffi_web/lib/src/database_file_system_web.dart#L72-L88
    final file = fs
        .xOpen(Sqlite3Filename(fs.xFullPathName(path)),
            SqlFlag.SQLITE_OPEN_READWRITE | SqlFlag.SQLITE_OPEN_CREATE)
        .file;
    try {
      file.xTruncate(0);
      file.xWrite(databaseBinary, 0);
    } finally {
      file.xClose();
    }
  }

  @override
  void initState() {
    super.initState();
    db = Future(() async {
      final sqlite3 = await _sqlite3;
      const path = 'my-original-data';
      final databaseBinary = await http
          .readBytes(Uri.parse('main.db')); // assume existing web/main.db
      _loadDatabase(sqlite3, path, databaseBinary);
      return sqlite3.open(path);
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: FutureBuilder<CommonDatabase>(
          future: db,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              const sql = 'SELECT id, value FROM greetings ORDER BY id;';
              final resultSet = snapshot.data!.select(
                  sql); // assume having table 'greeting' and its column 'id' and 'value'.
              return DataTable(
                columns: resultSet.columnNames
                    .map((e) => DataColumn(label: Text(e)))
                    .toList(),
                rows: resultSet.rows.map((row) {
                  return DataRow(
                      cells: row.map((cell) {
                    return DataCell(Text(cell.toString()));
                  }).toList());
                }).toList(),
              );
            } else if (snapshot.hasError) {
              return Text('${snapshot.error}');
            }

            // By default, show a loading spinner.
            return const CircularProgressIndicator();
          },
        ),
      ),
    );
  }
}
