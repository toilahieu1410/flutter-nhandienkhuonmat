import 'dart:io';
import 'dart:typed_data';

import 'package:face_recognition_with_images/ML/Recognition.dart';
import 'package:face_recognition_with_images/ML/Recognizer.dart';
import 'package:face_recognition_with_images/RegistrationScreen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

class RecognitionScreen extends StatefulWidget {
  const RecognitionScreen({Key? key}) : super(key: key);

  @override
  State<RecognitionScreen> createState() => _RecognitionScreenState();
}

class _RecognitionScreenState extends State<RecognitionScreen> {
  //TODO khai báo biến
  late ImagePicker imagePicker;
  File? _image;

  //TODO khai báo bộ dò tìm khuôn mặt
  late FaceDetector faceDetector;

  //TODO khai báo bộ nhận dạng khuôn mặt
  late Recognizer recognizer;

  @override
  void initState() {
    //TODO: thực hiện initState
    super.initState();
    imagePicker = ImagePicker();

    //TODO Khởi tạo bộ dò tìm khuôn mặt
    final options = FaceDetectorOptions();
    faceDetector = FaceDetector(options: options);

    //TODO khởi tạo bộ nhận dạng khuôn mặt
    recognizer = Recognizer();
  }

  //TODO chụp ảnh bằng camera
  _imgFromCamera() async {
    XFile? pickedFile = await imagePicker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        doFaceDetection();
      });
    }
  }

  //TODO chọn ảnh từ thư viện
  _imgFromGallery() async {
    XFile? pickedFile =
        await imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        doFaceDetection();
      });
    }
  }

  //TODO phát hiện khuôn mặt ở đây
  List<Face> faces = [];
  doFaceDetection() async {
    recognitions.clear();
    //TODO loại bỏ xoay ảnh từ camera
    _image = await removeRotation(_image!);

    image = await _image?.readAsBytes();
    image = await decodeImageFromList(image);

    //TODO truyền ảnh đầu vào cho bộ dò tìm và nhận diện khuôn mặt được phát hiện
    InputImage inputImage = InputImage.fromFile(_image!);
    faces = await faceDetector.processImage(inputImage);
    for (Face face in faces) {
      Rect faceRect = face.boundingBox;
      num left = faceRect.left < 0 ? 0 : faceRect.left;
      num top = faceRect.top < 0 ? 0 : faceRect.top;
      num right =
          faceRect.right > image.width ? image.width - 1 : faceRect.right;
      num bottom =
          faceRect.bottom > image.height ? image.height - 1 : faceRect.bottom;

      num width = right - left;
      num height = bottom - top;

      //TODO cắt khuôn mặt
      final bytes = _image!.readAsBytesSync();
      img.Image? faceImg = img.decodeImage(bytes!);
      img.Image faceImg2 = img.copyCrop(faceImg!,
          x: left.toInt(),
          y: top.toInt(),
          width: width.toInt(),
          height: height.toInt());

      Recognition recognition = recognizer.recognize(faceImg2, faceRect);
      if (recognition.distance > 1.25) {
        recognition.name = 'Unknow';
      }
      recognitions.add(recognition);
      //showFaceRegistrationDialogue(Uint8List.fromList(img.encodePng(faceImg2)), recognition);
    }
    drawRectangleAroundFaces();
  }

  //TODO loại bỏ xoay ảnh từ camera
  removeRotation(File inputImage) async {
    final img.Image? capturedImage =
        img.decodeImage(await File(inputImage!.path).readAsBytes());
    final img.Image orientedImage = img.bakeOrientation(capturedImage!);
    return await File(_image!.path).writeAsBytes(img.encodeJpg(orientedImage));
  }

  //TODO thực hiện nhận dạng khuôn mặt

  //TODO Đối thoại đăng ký khuôn mặt
  TextEditingController textEditingController = TextEditingController();
  showFaceRegistrationDialogue(Uint8List cropedFace, Recognition recognition) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title:
                  const Text('Đăng ký khuôn mặt', textAlign: TextAlign.center),
              alignment: Alignment.center,
              content: SizedBox(
                height: 340,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    Image.memory(
                      cropedFace,
                      width: 200,
                      height: 200,
                    ),
                    SizedBox(
                      width: 200,
                      child: TextField(
                        controller: textEditingController,
                        decoration: const InputDecoration(
                            fillColor: Colors.white,
                            filled: true,
                            hintText: 'Nhập tên'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                        onPressed: () {
                          textEditingController.text = '';
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                            content: Text('Khuôn mặt đã được đăng ký'),
                          ));
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            minimumSize: const Size(200, 40)),
                        child: const Text("Đăng ký")),
                  ],
                ),
              ),
              contentPadding: EdgeInsets.zero,
            ));
  }

  //TODO vẽ hình chữ nhật xung quanh các khuôn mặt
  var image;
  drawRectangleAroundFaces() async {
    image = await _image?.readAsBytes();
    image = await decodeImageFromList(image);
    print("${image.width}   ${image.height}");
    setState(() {
      recognitions;
      image;
      faces;
    });
  }

  List<Recognition> recognitions = [];

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          image != null
              ?
              // Container(
              //  margin: const EdgeInsets.only(top: 100),
              //  width: screenWidth - 50,
              //  height: screenWidth - 50,
              //  child: Image.file(_image!),
              // )
              Container(
                  margin: const EdgeInsets.only(
                      top: 60, left: 30, right: 30, bottom: 0),
                  child: FittedBox(
                    child: SizedBox(
                      width: image.width.toDouble(),
                      height: image.width.toDouble(),
                      child: CustomPaint(
                        painter: FacePainter(
                            facesList: recognitions, imageFile: image),
                      ),
                    ),
                  ))
              : Container(
                  margin: const EdgeInsets.only(top: 100),
                  child: Image.asset(
                    "images/logo.png",
                    width: screenWidth - 100,
                    height: screenWidth - 100,
                  ),
                ),
          Container(
            height: 50,
          ),

          //TODO phần hiển thị các nút để chọn và chụp ảnh
          Container(
            margin: const EdgeInsets.only(bottom: 50),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Card(
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(200)),
                  ),
                  child: InkWell(
                    onTap: () {
                      _imgFromGallery();
                    },
                    child: SizedBox(
                      width: screenWidth / 2 - 70,
                      height: screenWidth / 2 - 70,
                      child: Icon(Icons.image,
                          color: Colors.blue, size: screenWidth / 7),
                    ),
                  ),
                ),
                Card(
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(200)),
                  ),
                  child: InkWell(
                    onTap: () {
                      _imgFromCamera();
                    },
                    child: SizedBox(
                      width: screenWidth / 2 - 70,
                      height: screenWidth / 2 - 70,
                      child: Icon(Icons.camera,
                          color: Colors.blue, size: screenWidth / 7),
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class FacePainter extends CustomPainter {
  List<Recognition> facesList;
  dynamic imageFile;
  FacePainter({required this.facesList, @required this.imageFile});

  @override
  void paint(Canvas canvas, Size size) {
    if (imageFile != null) {
      canvas.drawImage(imageFile, Offset.zero, Paint());
    }

    Paint p = Paint();
    p.color = Colors.red;
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 3;

    for (Recognition rectangle in facesList) {
      canvas.drawRect(rectangle.location, p);

      TextSpan span = TextSpan(
          style: const TextStyle(color: Colors.white, fontSize: 30),
          text: "${rectangle.name}  ${rectangle.distance.toStringAsFixed(2)}");
      TextPainter tp = TextPainter(
          text: span,
          textAlign: TextAlign.left,
          textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(rectangle.location.left, rectangle.location.top));
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
