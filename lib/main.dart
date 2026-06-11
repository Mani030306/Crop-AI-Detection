import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Interpreter? interpreter;

  List<String> labels = [];
  Map<String, dynamic> diseaseData = {};

  File? image;

  String result = "📸 Upload a plant leaf image";
  String selectedLang = "en";

  final picker = ImagePicker();
  final FlutterTts tts = FlutterTts();

  final Map<String, Map<String, String>> uiText = {
    "en": {
      "treatment": "Treatment",
      "prevention": "Prevention",
      "confidence": "Confidence",
    },
    "ta": {
      "treatment": "சிகிச்சை",
      "prevention": "தடுப்பு",
      "confidence": "நம்பகத்தன்மை",
    },
    "hi": {
      "treatment": "उपचार",
      "prevention": "रोकथाम",
      "confidence": "विश्वास",
    },
    "ml": {
      "treatment": "ചികിത്സ",
      "prevention": "പ്രതിരോധം",
      "confidence": "വിശ്വാസം",
    }
  };

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  Future loadModel() async {
    final modelData = await rootBundle.load('assets/model.tflite');

    interpreter = Interpreter.fromBuffer(
      modelData.buffer.asUint8List(),
    );

    interpreter!.allocateTensors();

    final labelData =
        await rootBundle.loadString('assets/labels.txt');

    labels = labelData
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final jsonStr =
        await rootBundle.loadString('assets/disease_data.json');

    diseaseData = json.decode(jsonStr);
  }

  Future setTtsLanguage() async {
    await tts.setLanguage(
      selectedLang == "ta"
          ? "ta-IN"
          : selectedLang == "hi"
              ? "hi-IN"
              : selectedLang == "ml"
                  ? "ml-IN"
                  : "en-US",
    );

    await tts.setSpeechRate(0.5);
  }

  Future runModel(File file) async {
    img.Image? imageData =
        img.decodeImage(await file.readAsBytes());

    imageData = img.copyResize(
      imageData!,
      width: 224,
      height: 224,
    );

    var input = List.generate(
      1,
      (_) => List.generate(
        224,
        (y) => List.generate(
          224,
          (x) {
            final p = imageData!.getPixel(x, y);

            return [
              p.r / 255.0,
              p.g / 255.0,
              p.b / 255.0
            ];
          },
        ),
      ),
    );

    int outputSize =
        interpreter!.getOutputTensor(0).shape[1];

    var output =
        List.generate(1, (_) => List.filled(outputSize, 0.0));

    interpreter!.run(input, output);

    List<double> scores = List<double>.from(output[0]);

    // ✅ Sort top scores
    List<double> sortedScores = List.from(scores)
      ..sort((a, b) => b.compareTo(a));

    double top1 = sortedScores[0];
    double top2 = sortedScores[1];

    int maxIndex = scores.indexOf(top1);

    // ❌ Reject non-plant image
    if (top1 < 0.4) {
      setState(() {
        result =
            "❌ Please upload a clear plant leaf image";
      });
      return;
    }

    // ❌ Reject confused prediction
    if ((top1 - top2) < 0.15) {
      setState(() {
        result =
            "❌ Unclear image. Please upload a clearer plant leaf";
      });
      return;
    }

    String label = labels[maxIndex];

    var data = diseaseData[label];

    var t = uiText[selectedLang];

    String confidenceText =
        (top1 * 100).toStringAsFixed(2);

    String warning = "";

    if (top1 < 0.7) {
      warning =
          "⚠️ Low confidence prediction. Try clearer image.\n\n";
    }

    setState(() {
      result = """
$warning
🌿 ${data?[selectedLang]?['description'] ?? label}

💊 ${t?['treatment']}:
${data?[selectedLang]?['treatment'] ?? ""}

🛡 ${t?['prevention']}:
${data?[selectedLang]?['prevention'] ?? ""}

📊 ${t?['confidence']}: $confidenceText%
""";
    });

    await setTtsLanguage();

    await tts.stop();

    await tts.speak(result);
  }

  Future pickImage(ImageSource source) async {
    await tts.stop();

    final picked =
        await picker.pickImage(source: source);

    if (picked == null) return;

    File file = File(picked.path);

    setState(() {
      image = file;
      result = "🔍 Analyzing...";
    });

    await runModel(file);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2f4f88),

      appBar: AppBar(
        backgroundColor: const Color(0xFF2f4f88),
        elevation: 0,

        title: const Text(
          "🌿 Green Gaze",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 28,
            letterSpacing: 1,
          ),
        ),

        actions: [

          DropdownButton<String>(
            value: selectedLang,

            dropdownColor: Colors.white,

            underline: Container(),

            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),

            items: const [
              DropdownMenuItem(
                value: "en",
                child: Text("EN"),
              ),
              DropdownMenuItem(
                value: "ta",
                child: Text("TA"),
              ),
              DropdownMenuItem(
                value: "hi",
                child: Text("HI"),
              ),
              DropdownMenuItem(
                value: "ml",
                child: Text("ML"),
              ),
            ],

            onChanged: (value) {
              setState(() {
                selectedLang = value!;
              });
            },
          ),

          IconButton(
            icon: const Icon(
              Icons.volume_up,
              color: Colors.white,
              size: 30,
            ),
            onPressed: () async {
              await setTtsLanguage();
              await tts.speak(result);
            },
          ),
        ],
      ),

      body: Column(
        children: [

          const SizedBox(height: 25),

          image == null
              ? Container(
                  height: 180,
                  width: 180,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.image,
                    size: 100,
                    color: Colors.white70,
                  ),
                )
              : ClipRRect(
                  borderRadius:
                      BorderRadius.circular(20),
                  child: Image.file(
                    image!,
                    height: 220,
                    width: 220,
                    fit: BoxFit.cover,
                  ),
                ),

          const SizedBox(height: 25),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),

              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius:
                    BorderRadius.circular(20),
              ),

              child: Text(
                result,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          const Spacer(),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [

                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        pickImage(ImageSource.camera),

                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor:
                          Colors.deepPurple,

                      padding:
                          const EdgeInsets.symmetric(
                        vertical: 16,
                      ),

                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(30),
                      ),
                    ),

                    child: const Text(
                      "Camera",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        pickImage(ImageSource.gallery),

                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor:
                          Colors.deepPurple,

                      padding:
                          const EdgeInsets.symmetric(
                        vertical: 16,
                      ),

                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(30),
                      ),
                    ),

                    child: const Text(
                      "Gallery",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}