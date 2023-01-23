import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tflite/flutter_tflite.dart';
import 'dart:math' as math;

List<CameraDescription>? cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    debugPrint('Error: $e.code\nError Message: $e.message');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cats vs Dogs',
      theme: ThemeData(
        brightness: Brightness.dark,
      ),
      home: const Home(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  String tipo = "";
  animal(String animal) {
    setState(() {
      tipo = animal;
    });
  }

  @override
  void initState() {
    super.initState();
    loadModel().then((_) {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Camera(cameras: cameras!, tipo: animal),
          Center(
            child: Text(
              tipo,
              style: const TextStyle(fontSize: 25, color: Colors.white70),
            ),
          )
        ],
      ),
    );
  }

  loadModel() async {
    await Tflite.loadModel(
      model: "assets/model_unquant.tflite",
      labels: "assets/model.txt",
    );
  }
}

class Camera extends StatefulWidget {
  final List<CameraDescription> cameras;
  final Function(String value) tipo;

  const Camera({super.key, required this.cameras, required this.tipo});

  @override
  State<Camera> createState() => _CameraState();
}

class _CameraState extends State<Camera> {
  CameraController? controller;
  bool isDetecting = false;

  @override
  void initState() {
    super.initState();
    if (widget.cameras.isEmpty) {
      debugPrint("Camara no encontrada");
    } else {
      controller = CameraController(widget.cameras[0], ResolutionPreset.high);
      controller?.initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        controller?.startImageStream((image) {
          if (!isDetecting) {
            isDetecting = true;
            Tflite.runModelOnFrame(
              bytesList: image.planes.map((plane) {
                return plane.bytes;
              }).toList(),
              imageHeight: image.height,
              imageWidth: image.width,
              numResults: 2,
            ).then((value) {
              widget.tipo(value![0]["label"]);
              isDetecting = false;
            });
          }
        });
      });
    }
  }

  @override
  void dispose() {
    controller?.stopImageStream();
    controller?.dispose();
    Tflite.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return const SizedBox();
    }

    var tmp = MediaQuery.of(context).size;
    var screenH = math.max(tmp.height, tmp.width);
    var screenW = math.min(tmp.height, tmp.width);
    tmp = controller!.value.previewSize!;
    var previewH = math.max(tmp.height, tmp.width);
    var previewW = math.min(tmp.height, tmp.width);
    var screenRatio = screenH / screenW;
    var previewRatio = previewH / previewW;

    return OverflowBox(
        maxHeight: screenRatio > previewRatio
            ? screenH
            : screenW / previewW * previewH,
        maxWidth: screenRatio > previewRatio
            ? screenH / previewH * previewW
            : screenW,
        child: CameraPreview(controller!));
  }
}
