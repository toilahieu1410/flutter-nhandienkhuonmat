import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../DB/DatabaseHelper.dart';
import '../HomeScreen.dart';
import 'Recognition.dart';

class Recognizer {
  late Interpreter interpreter;
  late InterpreterOptions _interpreterOptions;
  static const int WIDTH = 160;
  static const int HEIGHT = 160;
  final dbHelper = DatabaseHelper();
  Map<String, Recognition> registered = Map();
  @override
  String get modelName => 'assets/mobile_face_net.tflite';

  Recognizer({int? numThreads}) {
    _interpreterOptions = InterpreterOptions();

    if (numThreads != null) {
      _interpreterOptions.threads = numThreads;
    }
    loadModel();
    initDB();
  }

  initDB() async {
    await dbHelper.init();
    loadRegisteredFaces();
  }

  void loadRegisteredFaces() async {
    final allRows = await dbHelper.queryAllRows();
    for (final row in allRows) {
      String name = row[DatabaseHelper.columnName];
      String embeddingString = row[DatabaseHelper.columnEmbedding];

      try {
        // Sử dụng jsonDecode để chuyển đổi chuỗi JSON thành List<double>
        List<dynamic> embeddingJson = jsonDecode(embeddingString);
        List<double> embd =
            embeddingJson.cast<double>(); // Chuyển đổi từ dynamic sang double

        Recognition recognition = Recognition(name, Rect.zero, embd, 0);
        registered.putIfAbsent(name, () => recognition);
        print('Loaded registered face: $name with embeddings: $embd');
      } catch (e) {
        print('Error parsing embeddings for $name: $e');
      }
    }
  }

  void registerFaceInDB(String name, List<double> embedding) async {
    // Chuyển đổi embedding thành chuỗi JSON để tránh lỗi định dạng
    String embeddingString = jsonEncode(embedding);
    Map<String, dynamic> row = {
      DatabaseHelper.columnName: name,
      DatabaseHelper.columnEmbedding: embeddingString
    };
    final id = await dbHelper.insert(row);
    print('inserted row id: $id');
  }

  Future<void> loadModel() async {
    try {
      interpreter = await Interpreter.fromAsset(modelName);
    } catch (e) {
      print('Unable to create interpreter, Caught Exception: ${e.toString()}');
    }
  }

  List<dynamic> imageToArray(img.Image inputImage) {
    img.Image resizedImage =
        img.copyResize(inputImage!, width: WIDTH, height: HEIGHT);
    List<double> flattenedList = resizedImage.data!
        .expand((channel) => [channel.r, channel.g, channel.b])
        .map((value) => value.toDouble())
        .toList();
    Float32List float32Array = Float32List.fromList(flattenedList);
    int channels = 3;
    int height = HEIGHT;
    int width = WIDTH;
    Float32List reshapedArray = Float32List(1 * height * width * channels);
    for (int c = 0; c < channels; c++) {
      for (int h = 0; h < height; h++) {
        for (int w = 0; w < width; w++) {
          int index = c * height * width + h * width + w;
          reshapedArray[index] =
              (float32Array[c * height * width + h * width + w] - 127.5) /
                  127.5;
        }
      }
    }
    return reshapedArray.reshape([1, 160, 160, 3]);
  }

  Recognition recognize(img.Image image, Rect location) {
    //TODO cắt khuôn mặt từ hình ảnh, thay đổi kích thước và chuyển đổi nó thành mảng số thực (float array)
    var input = imageToArray(image);
    print(input.shape.toString());

    //TODO mảng đầu ra
    List output = List.filled(1 * 512, 0).reshape([1, 512]);

    //TODO thực hiện suy luận
    final runs = DateTime.now().millisecondsSinceEpoch;
    interpreter.run(input, output);
    final run = DateTime.now().millisecondsSinceEpoch - runs;
    print('Time to run inference: $run ms$output');

    //TODO chuyển đổi danh sách dynamic thành danh sách double
    List<double> outputArray = output.first.cast<double>();

    //TODO tìm kiếm embedding gần nhất trong cơ sở dữ liệu và trả về cặp tương ứng
    Pair pair = findNearest(outputArray);
    print("distance= ${pair.distance}");

    return Recognition(pair.name, location, outputArray, pair.distance);
  }

  //TODO tìm kiếm embedding gần nhất trong cơ sở dữ liệu và trả về cặp chứa thông tin khuôn mặt đã đăng ký nào giống nhất
  findNearest(List<double> emb) {
    Pair pair = Pair("Unknown", -5);
    for (MapEntry<String, Recognition> item in registered.entries) {
      final String name = item.key;
      List<double> knownEmb = item.value.embeddings;
      double distance = 0;
      for (int i = 0; i < emb.length; i++) {
        double diff = emb[i] - knownEmb[i];
        distance += diff * diff;
      }
      distance = sqrt(distance);
      if (pair.distance == -5 || distance < pair.distance) {
        pair.distance = distance;
        pair.name = name;
      }
    }
    return pair;
  }

  void close() {
    interpreter.close();
  }
}

class Pair {
  String name;
  double distance;
  Pair(this.name, this.distance);
}
